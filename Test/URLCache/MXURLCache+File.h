//
//  MXURLCache+File.h
//  MoxtraDesktopAgent
//
//  Created by sunny on 17/4/13.
//  Copyright © 2017年 moxtra. All rights reserved.
//

#import "MXURLCache.h"

@interface MXURLCache (File)

- (void)saveToCachesWithRequest:(NSURLRequest*)request response:(NSCachedURLResponse*)cachedResponse expirationDate:(NSDate *)expirationDate;
- (NSUInteger)fetch_currentFolderSize;
- (long long)fetch_currentFileSize:(NSString *)filePath;
- (void)addToCachedFileDictionryWithFile:(NSString *)filePath;

@end
