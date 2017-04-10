//
//  MXURLCache.m
//  Test
//
//  Created by sunny on 17/4/6.
//  Copyright © 2017年 sunny. All rights reserved.
//

#import "MXURLCache.h"
#import "Reachability.h"
#import "Util.h"

@interface MXURLCache(private)

- (NSString *)cacheFolder;
- (NSString *)cacheFilePath:(NSString *)file;
- (NSString *)cacheRequestFileName:(NSString *)requestUrl;
- (NSString *)cacheRequestOtherInfoFileName:(NSString *)requestUrl;
- (NSCachedURLResponse *)dataFromRequest:(NSURLRequest *)request;
- (void)deleteCacheFolder;

@end

@implementation MXURLCache

- (id)initWithMemoryCapacity:(NSUInteger)memoryCapacity diskCapacity:(NSUInteger)diskCapacity diskPath:(NSString *)path cacheTime:(NSInteger)cacheTime
{
    if (self = [self initWithMemoryCapacity:memoryCapacity diskCapacity:diskCapacity diskPath:path])
    {
        self.cacheTime = cacheTime;
        if (path)
            self.diskPath = path;
        else
            self.diskPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
        
        self.responseDictionary = [NSMutableDictionary dictionaryWithCapacity:0];
    }
    return self;
}

- (NSCachedURLResponse *)cachedResponseForRequest:(NSURLRequest *)request
{
    if ([request.HTTPMethod compare:@"GET"] != NSOrderedSame)
    {
        return [super cachedResponseForRequest:request];
    }
    
    return [self dataFromRequest:request];
}

- (void)removeAllCachedResponses
{
    [super removeAllCachedResponses];
    
    [self deleteCacheFolder];
}

- (void)removeCachedResponseForRequest:(NSURLRequest *)request {
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

#pragma mark - private method
- (NSString *)cacheFolder
{
    NSString *bundleId = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
    return bundleId == nil ? @"URLCACHE" : bundleId;
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

- (NSCachedURLResponse *)dataFromRequest:(NSURLRequest *)request
{
    NSString *url = request.URL.absoluteString;
    NSString *fileName = [self cacheRequestFileName:url];
    NSString *otherInfoFileName = [self cacheRequestOtherInfoFileName:url];
    NSString *filePath = [self cacheFilePath:fileName];
    NSString *otherInfoPath = [self cacheFilePath:otherInfoFileName];
    NSDate *date = [NSDate date];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:filePath])
    {
        BOOL expire = false;
        NSDictionary *otherInfo = [NSDictionary dictionaryWithContentsOfFile:otherInfoPath];
        
        if (self.cacheTime > 0)
        {
            NSInteger createTime = [[otherInfo objectForKey:@"time"] intValue];
            if (createTime + self.cacheTime < [date timeIntervalSince1970])
            {
                expire = true;
            }
        }
        
        if (expire == false)
        {
            NSLog(@"data from cache ...");
            NSData *data = [NSData dataWithContentsOfFile:filePath];
            NSURLResponse *response = [[NSURLResponse alloc] initWithURL:request.URL
                                                                MIMEType:[otherInfo objectForKey:@"MIMEType"]
                                                   expectedContentLength:data.length
                                                        textEncodingName:[otherInfo objectForKey:@"textEncodingName"]];
            NSCachedURLResponse *cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:response data:data];
            [self removeCachedResponseForRequest:request];
            [self saveOrUpdateCacheWith:request];
            return cachedResponse;
        }
        else
        {
            NSLog(@"cache expire ... ");
            [fileManager removeItemAtPath:filePath error:nil];
            [fileManager removeItemAtPath:otherInfoPath error:nil];
        }
    }
    
    if (![Reachability networkAvailable])
    {
        return nil;
    }
    
    return [self saveOrUpdateCacheWith:request];
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
                [self.responseDictionary removeObjectForKey:url];
                
                //save to cache
                NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%f", [date timeIntervalSince1970]], @"time",
                                      response.MIMEType, @"MIMEType",
                                      response.textEncodingName, @"textEncodingName", nil];
                [dict writeToFile:otherInfoPath atomically:YES];
                [data writeToFile:filePath atomically:YES];
                NSLog(@"save to cache");
                
                cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:response data:data];
            }
            
        }] resume];
        
        return cachedResponse;
    }
    
    return nil;
}

@end
