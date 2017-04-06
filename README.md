# URLCacheDemo

-	url本地缓存的示例
	-	使用	
	-	在运行的时候直接设置
	-	MXURLCache *urlCache = [[MXURLCache alloc] initWithMemoryCapacity:20 * 1024 * 1024
                                                                     diskCapacity:200 * 1024 * 1024
                                                                         diskPath:nil
                                                                        cacheTime:0];
        [MXURLCache setSharedURLCache:urlCache];		