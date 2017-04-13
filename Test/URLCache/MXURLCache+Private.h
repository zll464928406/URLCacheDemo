//
//  MXURLCache+Private.h
//  MoxtraTest
//
//  Created by sunny on 17/4/10.
//  Copyright © 2017年 sunny. All rights reserved.
//

#import "MXURLCache.h"

@interface MXURLCache (Private)

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request;
+ (NSDate *)expirationDateFromHeaders:(NSDictionary *)headers withStatusCode:(NSInteger)status;

- (NSString *)cacheFolder;
- (NSString *)cacheFilePath:(NSString *)file;
- (NSString *)cacheRequestFileName:(NSString *)requestUrl;
- (NSString *)cacheRequestOtherInfoFileName:(NSString *)requestUrl;
- (void)deleteCacheFolder;

@end
