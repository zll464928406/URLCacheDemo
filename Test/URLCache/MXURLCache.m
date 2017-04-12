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

#define kMAX_SINGLECAPACITY 10*1024*1024
#define kMXDefaultMAXCacheInterval  60*60*48 //最大缓存时间
#define kMXDefaultMinCacheInterval  60*60  //过期时间超过这个数值的才进行缓存
#define kMXDefaultMinEXPIRATIONTIME 5*60   //距离过期时间小于此值时更新缓存
#define KFIRSTTIMEINSTALL_CACHE @"firstTimeInstall_cache"

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
        
        self.responseDictionary = [NSMutableDictionary dictionaryWithCapacity:0];
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
        NSLog(@"%@---", request.URL.absoluteString);
        return memoryResponse;
    }
    
    if ([request.HTTPMethod compare:@"GET"] != NSOrderedSame)
    {
        return [super cachedResponseForRequest:request];
    }
    
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
            //check if expirationDate
            NSDate *expirationDate = [otherInfo objectForKey:@"expirationDate"];
            NSDate *writeDate = [otherInfo objectForKey:@"writeDate"];
            NSLog(@"%@---%@", url,[expirationDate descriptionWithLocale:[NSLocale currentLocale]]);
            if ([expirationDate timeIntervalSinceNow] < kMXDefaultMinEXPIRATIONTIME || [[NSDate date] timeIntervalSinceDate:writeDate] > kMXDefaultMAXCacheInterval)
            {
                [self removeCachedResponseForRequest:request];
                
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
    }
    
    if (![Reachability networkAvailable])
    {
        return nil;
    }
    
    return nil;
}

-(void)storeCachedResponse:(NSCachedURLResponse *)cachedResponse forRequest:(NSURLRequest *)request
{
    request = [MXURLCache canonicalRequestForRequest:request];
    //NSLog(@"%@",request.URL.absoluteString);
    if (request.cachePolicy == NSURLRequestReloadIgnoringLocalCacheData
        || request.cachePolicy == NSURLRequestReloadIgnoringLocalAndRemoteCacheData
        || request.cachePolicy == NSURLRequestReloadIgnoringCacheData)
    {
        return;
    }
    
    [super storeCachedResponse:cachedResponse forRequest:request];
    
    NSString *url = request.URL.absoluteString;
    NSString *fileName = [self cacheRequestFileName:url];
    NSString *otherInfoFileName = [self cacheRequestOtherInfoFileName:url];
    NSString *filePath = [self cacheFilePath:fileName];
    NSString *otherInfoPath = [self cacheFilePath:otherInfoFileName];
    NSDate *date= [NSDate date];
    
    NSDictionary *headers = [(NSHTTPURLResponse *)cachedResponse.response allHeaderFields];
    
    NSURLCacheStoragePolicy storagePolicy = cachedResponse.storagePolicy;
    if ((storagePolicy == NSURLCacheStorageAllowed || (storagePolicy == NSURLCacheStorageAllowedInMemoryOnly))
        && [cachedResponse.response isKindOfClass:[NSHTTPURLResponse self]]
        && cachedResponse.data.length < kMAX_SINGLECAPACITY)
    {
        NSDictionary *headers = [(NSHTTPURLResponse *)cachedResponse.response allHeaderFields];
        // RFC 2616 section 13.3.4 says clients MUST use Etag in any cache-conditional request if provided by server
        //if ([headers objectForKey:@"Etag"])
        {
            NSDate *expirationDate = [MXURLCache expirationDateFromHeaders:headers
                                                            withStatusCode:((NSHTTPURLResponse *)cachedResponse.response).statusCode];
            //NSLog(@"%@",[expirationDate descriptionWithLocale:[NSLocale currentLocale]]);
            //NSLog(@"%lf",[expirationDate timeIntervalSinceNow] - kMXURLCacheInfoDefaultMinCacheInterval);
            if ((!expirationDate) || [expirationDate timeIntervalSinceNow] <= kMXDefaultMinCacheInterval)
            {
                // This response is not cacheable, headers said
                [self removeCachedResponseForRequest:request];
                
                return;
            }
            
            NSURLResponse *response = cachedResponse.response;
            NSData *data = cachedResponse.data;
            
            id boolExsite = [self.responseDictionary objectForKey:url];
            if (boolExsite == nil)
            {
                [self.responseDictionary setValue:[NSNumber numberWithBool:TRUE] forKey:url];
                if (response)
                {
                    @synchronized (self)
                    {
                        [self.responseDictionary removeObjectForKey:url];
                        
                        //save to cache
                        NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                                              date, @"writeDate",
                                              expirationDate, @"expirationDate",
                                              response.MIMEType, @"MIMEType",
                                              response.textEncodingName, @"textEncodingName",
                                              nil];
                        [dict writeToFile:otherInfoPath atomically:YES];
                        [data writeToFile:filePath atomically:YES];
                        //NSLog(@"save to cache");
                    }
                    
                }
            }
        }
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
@end
