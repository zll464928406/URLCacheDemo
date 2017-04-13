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
#import "MXURLCache+File.h"

#define kMAX_SINGLECAPACITY         10*1024*1024 //单个文件的最大值
#define kMXDefaultMAXCacheInterval  60*60*24*30  //最大缓存时间
#define kMXDefaultMinCacheInterval  60*60        //过期时间超过这个数值的才进行缓存
#define kMXDefaultMinEXPIRATIONTIME 5*60         //距离过期时间小于此值时更新缓存

@interface MXURLCache ()

@property(nonatomic, copy) NSString *diskPath;

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
        
        self.diskMAXCapacity = diskCapacity;
        self.responseDictionary = [NSMutableDictionary dictionary];
        self.currentCacheSize = [self fetch_currentFolderSize];
        if (self.currentCacheSize > diskCapacity)
        {
            [self removeAllCachedResponses];
        }
    }
    return self;
}

#pragma mark - Method from NSURLCache
- (NSCachedURLResponse *)cachedResponseForRequest:(NSURLRequest *)request
{
    request = [MXURLCache canonicalRequestForRequest:request];
    //NSLog(@"%@---", request.URL.absoluteString);
    NSCachedURLResponse *memoryResponse = [super cachedResponseForRequest:request];
    if (memoryResponse)
    {
        NSLog(@"%@---memoryResponse", request.URL.absoluteString);
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
    
    NSDictionary *headers = [(NSHTTPURLResponse *)cachedResponse.response allHeaderFields];
    
    NSURLCacheStoragePolicy storagePolicy = cachedResponse.storagePolicy;
    if ((storagePolicy == NSURLCacheStorageAllowed || (storagePolicy == NSURLCacheStorageAllowedInMemoryOnly))
        && [cachedResponse.response isKindOfClass:[NSHTTPURLResponse self]]
        && cachedResponse.data.length < kMAX_SINGLECAPACITY)
    {
        NSDictionary *headers = [(NSHTTPURLResponse *)cachedResponse.response allHeaderFields];
        // RFC 2616 section 13.3.4 says clients MUST use Etag in any cache-conditional request if provided by server
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
        
        [self saveToCachesWithRequest:request response:cachedResponse expirationDate:expirationDate];
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
    self.currentCacheSize -= [self fetch_currentFileSize:filePath];
    [self.cachedFileDictionry removeObjectForKey:filePath];
}

- (void)removeAllCachedResponses
{
    [super removeAllCachedResponses];
    self.currentCacheSize = 0;
    [self.cachedFileDictionry removeAllObjects];
    [self deleteCacheFolder];
}
@end
