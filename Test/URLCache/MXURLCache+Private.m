//
//  MXURLCache+Private.m
//  MoxtraTest
//
//  Created by sunny on 17/4/10.
//  Copyright © 2017年 sunny. All rights reserved.
//

#import "MXURLCache+Private.h"
#import "Util.h"

static float const kSDURLCacheLastModFraction = 0.1f; // 10% since Last-Modified suggested by RFC2616 section 13.2.4
static float const kSDURLCacheDefault = 3600; // Default cache expiration delay if none defined (1 hour)

@implementation MXURLCache (Private)

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    NSString *string = request.URL.absoluteString;
    NSRange hash = [string rangeOfString:@"#"];
    if (hash.location == NSNotFound)
        return request;
    
    NSMutableURLRequest *copy = [request mutableCopy];
    copy.URL = [NSURL URLWithString:[string substringToIndex:hash.location]];
    return copy;
}

/*
 * This method tries to determine the expiration date based on a response headers dictionary.
 */
+ (NSDate *)expirationDateFromHeaders:(NSDictionary *)headers withStatusCode:(NSInteger)status
{
    if (status != 200 && status != 203 && status != 300 && status != 301 && status != 302 && status != 307 && status != 410)
    {
        // Uncacheable response status code
        return nil;
    }
    
    // Check Pragma: no-cache
    NSString *pragma = [headers objectForKey:@"Pragma"];
    if (pragma && [pragma isEqualToString:@"no-cache"])
    {
        // Uncacheable response
        return nil;
    }
    
    // Define "now" based on the request
    NSString *date = [headers objectForKey:@"Date"];
    NSDate *now;
    if (date)
    {
        now = [MXURLCache dateFromHttpDateString:date];
    }
    else
    {
        // If no Date: header, define now from local clock
        now = [NSDate date];
    }
    
    // Look at info from the Cache-Control: max-age=n header
    NSString *cacheControl = [[headers objectForKey:@"Cache-Control"] lowercaseString];
    if (cacheControl)
    {
        NSRange foundRange = [cacheControl rangeOfString:@"no-store"];
        if (foundRange.length > 0)
        {
            // Can't be cached
            return nil;
        }
        
        NSInteger maxAge;
        foundRange = [cacheControl rangeOfString:@"max-age"];
        if (foundRange.length > 0)
        {
            NSScanner *cacheControlScanner = [NSScanner scannerWithString:cacheControl];
            [cacheControlScanner setScanLocation:foundRange.location + foundRange.length];
            [cacheControlScanner scanString:@"=" intoString:nil];
            if ([cacheControlScanner scanInteger:&maxAge])
            {
                if (maxAge > 0)
                {
                    return [[NSDate alloc] initWithTimeInterval:maxAge sinceDate:now];
                }
                else
                {
                    return nil;
                }
            }
        }
    }
    
    // If not Cache-Control found, look at the Expires header
    NSString *expires = [headers objectForKey:@"Expires"];
    if (expires)
    {
        NSTimeInterval expirationInterval = 0;
        NSDate *expirationDate = [MXURLCache dateFromHttpDateString:expires];
        if (expirationDate)
        {
            expirationInterval = [expirationDate timeIntervalSinceDate:now];
        }
        if (expirationInterval > 0)
        {
            // Convert remote expiration date to local expiration date
            return [NSDate dateWithTimeIntervalSinceNow:expirationInterval];
        }
        else
        {
            // If the Expires header can't be parsed or is expired, do not cache
            return nil;
        }
    }
    
    if (status == 302 || status == 307)
    {
        // If not explict cache control defined, do not cache those status
        return nil;
    }
    
    // If no cache control defined, try some heristic to determine an expiration date
    NSString *lastModified = [headers objectForKey:@"Last-Modified"];
    if (lastModified)
    {
        NSTimeInterval age = 0;
        NSDate *lastModifiedDate = [MXURLCache dateFromHttpDateString:lastModified];
        if (lastModifiedDate)
        {
            // Define the age of the document by comparing the Date header with the Last-Modified header
            age = [now timeIntervalSinceDate:lastModifiedDate];
        }
        if (age > 0)
        {
            return [NSDate dateWithTimeIntervalSinceNow:(age * kSDURLCacheLastModFraction)];
        }
        else
        {
            return nil;
        }
    }
    
    // If nothing permitted to define the cache expiration delay nor to restrict its cacheability, use a default cache expiration delay
    return [[NSDate alloc] initWithTimeInterval:kSDURLCacheDefault sinceDate:now];
}

+ (NSDate *)dateFromHttpDateString:(NSString *)httpDate
{
    static NSDateFormatter *RFC1123DateFormatter;
    static NSDateFormatter *ANSICDateFormatter;
    static NSDateFormatter *RFC850DateFormatter;
    NSDate *date = nil;
    
    @synchronized(self) // NSDateFormatter isn't thread safe
    {
        // RFC 1123 date format - Sun, 06 Nov 1994 08:49:37 GMT
        if (!RFC1123DateFormatter) RFC1123DateFormatter = CreateDateFormatter(@"EEE, dd MMM yyyy HH:mm:ss z");
        date = [RFC1123DateFormatter dateFromString:httpDate];
        if (!date)
        {
            // ANSI C date format - Sun Nov  6 08:49:37 1994
            if (!ANSICDateFormatter) ANSICDateFormatter = CreateDateFormatter(@"EEE MMM d HH:mm:ss yyyy");
            date = [ANSICDateFormatter dateFromString:httpDate];
            if (!date)
            {
                // RFC 850 date format - Sunday, 06-Nov-94 08:49:37 GMT
                if (!RFC850DateFormatter) RFC850DateFormatter = CreateDateFormatter(@"EEEE, dd-MMM-yy HH:mm:ss z");
                date = [RFC850DateFormatter dateFromString:httpDate];
            }
        }
    }
    
    return date;
}

static NSDateFormatter* CreateDateFormatter(NSString *format)
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    
    [dateFormatter setLocale:locale];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
    [dateFormatter setDateFormat:format];
    
    return dateFormatter;
}

- (NSString *)cacheFolder
{
    NSString *bundleId = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
    return bundleId == nil ? @"MOXTRAURLCACHE" : bundleId;
}

- (void)deleteCacheFolder
{
    NSString *path = [NSString stringWithFormat:@"%@/%@", self.diskPath, [self cacheFolder]];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:path error:nil];
}

- (NSString *)cacheFilePath:(NSString *)file
{
    NSString *path = [NSString stringWithFormat:@"%@/%@", self.diskPath, [self cacheFolder]];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir;
    if ([fileManager fileExistsAtPath:path isDirectory:&isDir] && isDir)
    {
        
    }
    else
    {
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return [NSString stringWithFormat:@"%@/%@", path, file];
}

- (NSString *)cacheRequestFileName:(NSString *)requestUrl
{
    return [Util md5Hash:requestUrl];
}

- (NSString *)cacheRequestOtherInfoFileName:(NSString *)requestUrl
{
    return [Util md5Hash:[NSString stringWithFormat:@"%@-otherInfo", requestUrl]];
}

@end
