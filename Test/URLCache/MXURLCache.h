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

- (id)initWithMemoryCapacity:(NSUInteger)memoryCapacity diskCapacity:(NSUInteger)diskCapacity diskPath:(NSString *)path cacheTime:(NSInteger)cacheTime;

@end
