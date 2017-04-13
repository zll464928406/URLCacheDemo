//
//  MXURLCache+File.m
//  MoxtraDesktopAgent
//
//  Created by sunny on 17/4/13.
//  Copyright © 2017年 moxtra. All rights reserved.
//

#import "MXURLCache+File.h"
#import "MXURLCache+Private.h"

@implementation MXURLCache (File)

- (void)saveToCachesWithRequest:(NSURLRequest*)request response:(NSCachedURLResponse*)cachedResponse expirationDate:(NSDate *)expirationDate
{
    NSString *url = request.URL.absoluteString;
    NSString *fileName = [self cacheRequestFileName:url];
    NSString *otherInfoFileName = [self cacheRequestOtherInfoFileName:url];
    NSString *filePath = [self cacheFilePath:fileName];
    NSString *otherInfoPath = [self cacheFilePath:otherInfoFileName];
    NSDate *date= [NSDate date];
    NSURLResponse *response = cachedResponse.response;
    NSData *data = cachedResponse.data;
    
    if (response)
    {
        [self.responseDictionary removeObjectForKey:url];
        
        if (self.diskMAXCapacity > 0 && self.currentCacheSize + data.length > self.diskMAXCapacity)
        {
            [self cleanDiskWithCompletionBlock:^{
                
                    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                                          date, @"writeDate",
                                          expirationDate, @"expirationDate",
                                          response.MIMEType, @"MIMEType",
                                          response.textEncodingName, @"textEncodingName",
                                          nil];
                @synchronized (self)
                {
                    [dict writeToFile:otherInfoPath atomically:YES];
                    [data writeToFile:filePath atomically:YES];
                    [self addToCachedFileDictionryWithFile:filePath];
                    self.currentCacheSize += data.length;
                    NSLog(@"save to cache");
                }
            }];
        }
        else
        {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                
                    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                                          date, @"writeDate",
                                          expirationDate, @"expirationDate",
                                          response.MIMEType, @"MIMEType",
                                          response.textEncodingName, @"textEncodingName",
                                          nil];
                @synchronized (self)
                {
                    [dict writeToFile:otherInfoPath atomically:YES];
                    [data writeToFile:filePath atomically:YES];
                    [self addToCachedFileDictionryWithFile:filePath];
                    self.currentCacheSize += data.length;
                    NSLog(@"save to cache");
                }
            });
        }
    }
}

- (void)cleanDiskWithCompletionBlock:(void(^)(void))completionBlock
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *resourceKeys = @[NSURLIsDirectoryKey, NSURLContentAccessDateKey, NSURLTotalFileAllocatedSizeKey];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        // Target half of our maximum cache size for this cleanup pass.
        const NSUInteger desiredCacheSize = self.diskMAXCapacity * 0.6f;
        
        // Delete files until we fall below our desired cache size.
        @synchronized (self)
        {
            // Sort the remaining cache files by their last modification time (oldest first).
            NSArray *sortedFiles = [self.cachedFileDictionry keysSortedByValueWithOptions:NSSortConcurrent
                                                                  usingComparator:^NSComparisonResult(id obj1, id obj2) {
                                                                      return [obj1[NSURLContentAccessDateKey] compare:obj2[NSURLContentAccessDateKey]];
                                                                  }];
            for (NSURL *fileURL in sortedFiles)
            {
                if ([fileManager removeItemAtURL:fileURL error:nil])
                {
                    NSDictionary *resourceValues = self.cachedFileDictionry[fileURL];
                    NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
                    [self.cachedFileDictionry removeObjectForKey:fileURL];
                    self.currentCacheSize -= [totalAllocatedSize unsignedIntegerValue];
                    
                    if (self.currentCacheSize < desiredCacheSize)
                    {
                        break;
                    }
                }
            }
        }
        
        if (completionBlock)
        {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                completionBlock();
            });
        }
    });
}

- (NSUInteger)fetch_currentFolderSize
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *diskCachePath = [NSString stringWithFormat:@"%@/%@", self.diskPath, [self cacheFolder]];
    NSURL *diskCacheURL = [NSURL fileURLWithPath:diskCachePath isDirectory:YES];
    NSArray *resourceKeys = @[NSURLIsDirectoryKey, NSURLContentAccessDateKey, NSURLTotalFileAllocatedSizeKey];
    
    // This enumerator prefetches useful properties for our cache files.
    NSDirectoryEnumerator *fileEnumerator = [fileManager enumeratorAtURL:diskCacheURL
                                              includingPropertiesForKeys:resourceKeys
                                                                 options:NSDirectoryEnumerationSkipsHiddenFiles
                                                            errorHandler:NULL];
    
    self.cachedFileDictionry = [NSMutableDictionary dictionary];
    NSUInteger currentCacheSize = 0;
    
    //  2. Storing file attributes for the size-based cleanup pass.
    NSMutableArray *urlsToDelete = [[NSMutableArray alloc] init];
    for (NSURL *fileURL in fileEnumerator)
    {
        NSDictionary *resourceValues = [fileURL resourceValuesForKeys:resourceKeys error:NULL];
        // Skip directories.
        if ([resourceValues[NSURLIsDirectoryKey] boolValue]) {
            continue;
        }
        // Store a reference to this file and account for its total size.
        NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
        currentCacheSize += [totalAllocatedSize unsignedIntegerValue];
        [self.cachedFileDictionry setObject:resourceValues forKey:fileURL];
    }
    
    self.currentCacheSize = currentCacheSize;
    return currentCacheSize;
}

- (void)addToCachedFileDictionryWithFile:(NSString *)filePath
{
    NSArray *resourceKeys = @[NSURLIsDirectoryKey, NSURLContentAccessDateKey, NSURLTotalFileAllocatedSizeKey];
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    NSDictionary *resourceValues = [fileURL resourceValuesForKeys:resourceKeys error:NULL];
    if ([resourceValues[NSURLIsDirectoryKey] boolValue]) {
        return;
    }
    [self.cachedFileDictionry setObject:resourceValues forKey:fileURL];
}

- (long long)fetch_currentFileSize:(NSString *)filePath
{
    NSFileManager* manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:filePath])
    {
        return [[manager attributesOfItemAtPath:filePath error:nil] fileSize];
    }
    return 0;
}
@end
