//
//  MXURLCache.m
//  Test
//
//  Created by sunny on 17/4/6.
//  Copyright © 2017年 sunny. All rights reserved.
//

#import "MXURLCache.h"
#import "Reachability.h"
#import "MXURLCache+Private.h"

<<<<<<< HEAD
#define kMAX_SINGLECAPACITY         10*1024*1024 //单个文件的最大值
#define kMXDefaultMAXCacheInterval  60*60*48     //最大缓存时间
#define kMXDefaultMinCacheInterval  60*60        //过期时间超过这个数值的才进行缓存
#define kMXDefaultMinEXPIRATIONTIME 5*60         //距离过期时间小于此值时更新缓存
=======
static NSTimeInterval const kMXURLCacheInfoDefaultMinCacheInterval = 5 * 60;
>>>>>>> parent of c2a04f0... change cache

@interface MXURLCache ()

@property(nonatomic, copy) NSString *diskPath;
@property(nonatomic, strong) NSMutableDictionary *responseDictionary;

@end

@implementation MXURLCache

- (id)initWithMemoryCapacity:(NSUInteger)memoryCapacity diskCapacity:(NSUInteger)diskCapacity diskPath:(NSString *)path cacheTime:(NSInteger)cacheTime
{
    if (self = [self initWithMemoryCapacity:memoryCapacity diskCapacity:diskCapacity diskPath:path])
    {
        if (path)
            self.diskPath = path;
        else
            self.diskPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
        
        self.responseDictionary = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark - Method from NSURLCache
- (NSCachedURLResponse *)cachedResponseForRequest:(NSURLRequest *)request
{
    request = [MXURLCache canonicalRequestForRequest:request];
    
    NSCachedURLResponse *memoryResponse = [super cachedResponseForRequest:request];
    if (memoryResponse)
    {
        return memoryResponse;
    }
    
    if ([request.HTTPMethod compare:@"GET"] != NSOrderedSame)
    {
        return [super cachedResponseForRequest:request];
    }
    
<<<<<<< HEAD
    NSString *url = request.URL.absoluteString;
    NSString *fileName = [self cacheRequestFileName:url];
    NSString *otherInfoFileName = [self cacheRequestOtherInfoFileName:url];
    NSString *filePath = [self cacheFilePath:fileName];
    NSString *otherInfoPath = [self cacheFilePath:otherInfoFileName];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:filePath])
    {
        NSDictionary *otherInfo = [NSDictionary dictionaryWithContentsOfFile:otherInfoPath];
        //check if expirationDate
        NSDate *expirationDate = [otherInfo objectForKey:@"expirationDate"];
        NSDate *writeDate = [otherInfo objectForKey:@"writeDate"];
        //NSLog(@"%@---%@", url,[expirationDate descriptionWithLocale:[NSLocale currentLocale]]);
        if ([expirationDate timeIntervalSinceNow] < kMXDefaultMinEXPIRATIONTIME || [[NSDate date] timeIntervalSinceDate:writeDate] > kMXDefaultMAXCacheInterval)
        {
            @synchronized (self)
            {
                [self removeCachedResponseForRequest:request];
            }
            return nil;
        }
        
        //date from cache
        NSLog(@"data from cache ...");
        NSData *data = [NSData dataWithContentsOfFile:filePath];
        NSURLResponse *response = [[NSURLResponse alloc] initWithURL:request.URL
                                                            MIMEType:[otherInfo objectForKey:@"MIMEType"]
                                               expectedContentLength:data.length
                                                    textEncodingName:[otherInfo objectForKey:@"textEncodingName"]];
        NSCachedURLResponse *cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:response data:data];
        
        return cachedResponse;
    }
    
    if (![Reachability networkAvailable])
    {
        return nil;
    }
    
    return nil;
=======
    return [self dataFromRequest:request];
>>>>>>> parent of c2a04f0... change cache
}

-(void)storeCachedResponse:(NSCachedURLResponse *)cachedResponse forRequest:(NSURLRequest *)request
{
    request = [MXURLCache canonicalRequestForRequest:request];
    if (request.cachePolicy == NSURLRequestReloadIgnoringLocalCacheData
        || request.cachePolicy == NSURLRequestReloadIgnoringLocalAndRemoteCacheData
        || request.cachePolicy == NSURLRequestReloadIgnoringCacheData)
    {
        // When cache is ignored for read, it's a good idea not to store the result as well as this option
        // have big chance to be used every times in the future for the same request.
        // NOTE: This is a change regarding default URLCache behavior
        return;
    }
    
    [super storeCachedResponse:cachedResponse forRequest:request];
    
    NSString *url = request.URL.absoluteString;
    NSString *fileName = [self cacheRequestFileName:url];
    NSString *otherInfoFileName = [self cacheRequestOtherInfoFileName:url];
    NSString *filePath = [self cacheFilePath:fileName];
    NSString *otherInfoPath = [self cacheFilePath:otherInfoFileName];
    
    NSURLCacheStoragePolicy storagePolicy = cachedResponse.storagePolicy;
    if ((storagePolicy == NSURLCacheStorageAllowed || (storagePolicy == NSURLCacheStorageAllowedInMemoryOnly))
        && [cachedResponse.response isKindOfClass:[NSHTTPURLResponse self]]
        )
    {
        NSDictionary *headers = [(NSHTTPURLResponse *)cachedResponse.response allHeaderFields];
        // RFC 2616 section 13.3.4 says clients MUST use Etag in any cache-conditional request if provided by server
<<<<<<< HEAD
        NSDate *expirationDate = [MXURLCache expirationDateFromHeaders:headers
                                                        withStatusCode:((NSHTTPURLResponse *)cachedResponse.response).statusCode];
        //NSLog(@"%@",[expirationDate descriptionWithLocale:[NSLocale currentLocale]]);
        //NSLog(@"%lf",[expirationDate timeIntervalSinceNow] - kMXURLCacheInfoDefaultMinCacheInterval);
        if (![headers objectForKey:@"Etag"])
        {
            if ((!expirationDate) || [expirationDate timeIntervalSinceNow] <= kMXDefaultMinCacheInterval)
            {
                // This response is not cacheable, headers said
                [self removeCachedResponseForRequest:request];
                
                return;
            }
        }
        
        NSURLResponse *response = cachedResponse.response;
        NSData *data = cachedResponse.data;
        if (response)
        {
            @synchronized (self)
            {
                [self.responseDictionary removeObjectForKey:url];
=======
        if (![headers objectForKey:@"Etag"])
        {
            NSDate *expirationDate = [MXURLCache expirationDateFromHeaders:headers
                                                            withStatusCode:((NSHTTPURLResponse *)cachedResponse.response).statusCode];
            if (!expirationDate || [expirationDate timeIntervalSinceNow] - kMXURLCacheInfoDefaultMinCacheInterval <= 0)
            {
                // This response is not cacheable, headers said
                NSFileManager *fileManager = [NSFileManager defaultManager];
                if ([fileManager fileExistsAtPath:filePath])
                {
                    [fileManager removeItemAtPath:filePath error:nil];
                    [fileManager removeItemAtPath:otherInfoPath error:nil];
                }
                return;
>>>>>>> parent of c2a04f0... change cache
            }
            
            //save to cache
            NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                                  date, @"writeDate",
                                  expirationDate, @"expirationDate",
                                  response.MIMEType, @"MIMEType",
                                  response.textEncodingName, @"textEncodingName",
                                  nil];
            [dict writeToFile:otherInfoPath atomically:YES];
            [data writeToFile:filePath atomically:YES];
            NSLog(@"save to cache");
        }
        
        [self saveOrUpdateCacheWith:request];
    }
}

- (void)removeCachedResponseForRequest:(NSURLRequest *)request
{
    [super removeCachedResponseForRequest:request];
    
    NSString *url = request.URL.absoluteString;
    NSString *fileName = [self cacheRequestFileName:url];
    NSString *otherInfoFileName = [self cacheRequestOtherInfoFileName:url];
    NSString *filePath = [self cacheFilePath:fileName];
    NSString *otherInfoPath = [self cacheFilePath:otherInfoFileName];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:filePath error:nil];
    [fileManager removeItemAtPath:otherInfoPath error:nil];
}

- (void)removeAllCachedResponses
{
    [super removeAllCachedResponses];
    [self deleteCacheFolder];
}

#pragma mark - Private Method
- (NSCachedURLResponse *)dataFromRequest:(NSURLRequest *)request
{
    NSString *url = request.URL.absoluteString;
    NSString *fileName = [self cacheRequestFileName:url];
    NSString *otherInfoFileName = [self cacheRequestOtherInfoFileName:url];
    NSString *filePath = [self cacheFilePath:fileName];
    NSString *otherInfoPath = [self cacheFilePath:otherInfoFileName];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:filePath])
    {
        @synchronized (self)
        {
            NSDictionary *otherInfo = [NSDictionary dictionaryWithContentsOfFile:otherInfoPath];
            
            NSLog(@"data from cache ...");
            NSData *data = [NSData dataWithContentsOfFile:filePath];
            NSURLResponse *response = [[NSURLResponse alloc] initWithURL:request.URL
                                                                MIMEType:[otherInfo objectForKey:@"MIMEType"]
                                                   expectedContentLength:data.length
                                                        textEncodingName:[otherInfo objectForKey:@"textEncodingName"]];
            NSCachedURLResponse *cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:response data:data];
            return cachedResponse;
        }
    }
    
    if (![Reachability networkAvailable])
    {
        return nil;
    }
    
    return nil;
}

- (NSCachedURLResponse *)saveOrUpdateCacheWith:(NSURLRequest *)request
{
    //sendSynchronousRequest . save or update cache
    NSString *url = request.URL.absoluteString;
    NSString *fileName = [self cacheRequestFileName:url];
    NSString *otherInfoFileName = [self cacheRequestOtherInfoFileName:url];
    NSString *filePath = [self cacheFilePath:fileName];
    NSString *otherInfoPath = [self cacheFilePath:otherInfoFileName];
    NSDate *date = [NSDate date];
    
    __block NSCachedURLResponse * cachedResponse = nil;
    id boolExsite = [self.responseDictionary objectForKey:url];
    if (boolExsite == nil)
    {
        [self.responseDictionary setValue:[NSNumber numberWithBool:TRUE] forKey:url];
        
        [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            
            if (error)
            {
                NSLog(@"error : %@", error);
                NSLog(@"not cached: %@", request.URL.absoluteString);
                cachedResponse = nil;
            }
            
            if (response && data)
            {
                @synchronized (self)
                {
                    [self.responseDictionary removeObjectForKey:url];
                    
                    //save to cache
                    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%f", [date timeIntervalSince1970]], @"time",
                                          response.MIMEType, @"MIMEType",
                                          response.textEncodingName, @"textEncodingName", nil];
                    [dict writeToFile:otherInfoPath atomically:YES];
                    [data writeToFile:filePath atomically:YES];
                    NSLog(@"save to cache");
                }
                
                cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:response data:data];
            }
            
        }] resume];
        
        return cachedResponse;
    }
    
    return nil;
}

@end
