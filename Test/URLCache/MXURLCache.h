//
//  MXURLCache.h
//  Test
//
//  Created by sunny on 17/4/6.
//  Copyright © 2017年 sunny. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MXURLCache : NSURLCache

@property(nonatomic, readonly, copy) NSString *diskPath;
@property(nonatomic, readwrite, strong) NSMutableDictionary *responseDictionary;
@property(nonatomic, readwrite, assign) NSInteger diskMAXCapacity;
@property(nonatomic, readwrite, assign) NSInteger currentCacheSize;
@property(nonatomic, readwrite, strong) NSMutableDictionary *cachedFileDictionry;

- (id)initWithMemoryCapacity:(NSUInteger)memoryCapacity diskCapacity:(NSUInteger)diskCapacity diskPath:(NSString *)path cacheTime:(NSInteger)cacheTime;

@end
