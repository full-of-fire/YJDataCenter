//
//  YJCache.m
//  YJCache
//
//  Created by yj on 17/3/20.
//  Copyright © 2017年 yj. All rights reserved.
//

#import "YJCache.h"
#import <CommonCrypto/CommonDigest.h>
#import <UIKit/UIKit.h>

@interface YJCache ()
@property (strong,nonatomic) NSCache *memoryCache;
@property (copy,nonatomic) NSString *disCachePath;
@property (strong,nonatomic) dispatch_queue_t ioQueue;
@property (strong,nonatomic) NSFileManager *fileManger;
@end
NSInteger const KYJDefaultCacheAge = 7*24*60*60;
//NSInteger const KYJDefaultCacheAge = 5;
@implementation YJCache

+ (instancetype)sharedCache {

    static YJCache *instance = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    
    return instance;
    
    
  
}


- (instancetype)init {

    return [self initWithName:@"YJDefault"];
}

- (instancetype)initWithName:(NSString*)name {
   
    NSString *disCachePath = [self p_disCachePathWithName:name];
    return [self initWithName:name disCacheDirectory:disCachePath];
}



- (instancetype)initWithName:(NSString*)name disCacheDirectory:(NSString*)directory
{
    self = [super init];
    if (self) {
        
        // 内存缓存
        _memoryCache = [[NSCache alloc] init];
        _memoryCache.name = name;
        _memoryCache.countLimit = NSUIntegerMax;
        
        
        _maxCacheAge = KYJDefaultCacheAge;
        
        _ioQueue = dispatch_queue_create("com.iimedia.YJCache", DISPATCH_QUEUE_SERIAL);
        
        _shouldCahceInMemory = YES;
    
        dispatch_sync(_ioQueue, ^{
           
            _fileManger = [NSFileManager defaultManager];
        });
        
        if (directory != nil) {
            
            _disCachePath = [directory stringByAppendingPathComponent:name];
        }
        else{
        
            _disCachePath = [self p_disCachePathWithName:name];
        }
        
        NSLog(@"----disCachePath = %@",_disCachePath);
        
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(p_clearMemory)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(p_cleanDisk)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];
        
    }
    return self;
}


#pragma mark - public

- (void)yj_cacheObject:(id<NSCoding>)object forKey:(NSString *)key {

    NSAssert(object!=nil, @"缓存对象不能为空");
    NSAssert(key!= nil, @"缓存key值不能为空");
    
    //1. 保存到内存中
    if (_shouldCahceInMemory) {
        
        [self.memoryCache setObject:object forKey:key];
    }
    //2. 保存到本地磁盘
    dispatch_async(_ioQueue, ^{
       
      
        // 创建文件目录
        if (![_fileManger fileExistsAtPath:_disCachePath]) {
            
            [_fileManger createDirectoryAtPath:_disCachePath withIntermediateDirectories:YES attributes:nil error:nil];
        }
        
       
        NSString *fullCachePath = [self p_fullCachePathWithKey:key];
        
        // 归档
        [NSKeyedArchiver archiveRootObject:object toFile:fullCachePath];
        
     
        
    });
    
    
    
    
}

- (id<NSCoding>)yj_objectForKey:(NSString *)key {

    NSAssert(key!=nil, @"key值不能为空...");
    
    id object = [self.memoryCache objectForKey:key];
    
    if (!object) {
        
        NSString *fullCachePath = [self p_fullCachePathWithKey:key];
        
        object = [NSKeyedUnarchiver unarchiveObjectWithFile:fullCachePath];
        
        [self.memoryCache setObject:object forKey:key];
        
    }
    
    return object;
}
- (void)yj_objectForKey:(NSString*)key complteHanlder:(void(^)(id<NSCoding>object))complteHanlder {

    NSAssert(key!=nil, @"key值不能为空...");
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
       
        id object = [self.memoryCache objectForKey:key];
        
        if (!object) {
            
            NSString *fullCachePath = [self p_fullCachePathWithKey:key];
            object = [NSKeyedUnarchiver unarchiveObjectWithFile:fullCachePath];
            
            [self.memoryCache setObject:object forKey:key];
        }
            
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (complteHanlder) {
                
                complteHanlder(object);
            }
        });
        
    });
    
}

- (void)yj_removeObjectForKey:(NSString *)key {

    NSAssert(key!=nil, @"key值不能为空...");
    if (_shouldCahceInMemory) {
        
        [self.memoryCache removeObjectForKey:key];
    }
    
    dispatch_async(_ioQueue, ^{
       
        
        NSString *fullCachePath = [self p_fullCachePathWithKey:key];
        
        [_fileManger removeItemAtPath:fullCachePath error:nil];
        
    });
    
}


- (void)yj_removeAllObjects {

    if (_shouldCahceInMemory) {
        
        [self p_clearMemory];
    }
    
    [self p_clearDisk];
}

#pragma mark - setters 

- (void)setMaxMemoryCountList:(NSUInteger)maxMemoryCountList {

    self.memoryCache.countLimit = maxMemoryCountList;
}



#pragma mark - private 

- (NSString*)p_disCachePathWithName:(NSString*)name {

    return  [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:name];
}

- (NSString *)p_cachedFileNameForKey:(NSString *)key {
    const char *str = [key UTF8String];
    if (str == NULL) {
        str = "";
    }
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    NSString *filename = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%@",
                          r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10],
                          r[11], r[12], r[13], r[14], r[15], [[key pathExtension] isEqualToString:@""] ? @"" : [NSString stringWithFormat:@".%@", [key pathExtension]]];
    
    return filename;
}


- (NSString*)p_fullCachePathWithKey:(NSString*)key {

    NSString *cachePathKey = [self p_cachedFileNameForKey:key];
    NSString *fullCachePath = [_disCachePath stringByAppendingPathComponent:cachePathKey];
    return fullCachePath;
}


- (void)p_clearMemory {

    [_memoryCache removeAllObjects];
}

- (void)p_clearDisk {

    dispatch_async(_ioQueue, ^{
        
        [_fileManger removeItemAtPath:_disCachePath error:nil];
        
        
        [_fileManger createDirectoryAtPath:_disCachePath withIntermediateDirectories:YES attributes:nil error:nil];
        
    });
}

- (void)p_cleanDisk {

    NSLog(@"----给我调用一下");
    
    
    dispatch_async(self.ioQueue, ^{
        
        NSURL *diskCacheURL = [NSURL fileURLWithPath:self.disCachePath isDirectory:YES];
        
        NSArray *resourceKeys = @[NSURLIsDirectoryKey,NSURLContentModificationDateKey,NSURLTotalFileAllocatedSizeKey];
        
        NSDirectoryEnumerator *fileEnumerator = [_fileManger enumeratorAtURL:diskCacheURL includingPropertiesForKeys:resourceKeys options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:nil];
        
        NSDate *expirationDate = [NSDate dateWithTimeIntervalSinceNow:-self.maxCacheAge];
        
        NSMutableDictionary *cacheFiles = [NSMutableDictionary dictionary];
        NSUInteger currentCacheSize = 0;
        
        NSMutableArray *urlsToDelete = [NSMutableArray array];
        
        for (NSURL *fileURL in fileEnumerator) {
            
            NSDictionary *resourceValues = [fileURL resourceValuesForKeys:resourceKeys error:NULL];
            
            //跳过文件目录
            if ([resourceValues[NSURLIsDirectoryKey] boolValue]) {
                
                continue;
            }
            
            //找出过期的文件
            NSDate *modifiedDate = resourceValues[NSURLContentModificationDateKey];
            
            if ([[modifiedDate laterDate:expirationDate] isEqualToDate:expirationDate]) {
                
                [urlsToDelete addObject:fileURL];
                continue;
            }
            
            NSNumber *totalAlloctedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
            currentCacheSize +=[totalAlloctedSize unsignedIntegerValue];
            
            [cacheFiles setObject:resourceValues forKey:fileURL];
        }
        
        
        //删除过期的文件
        for (NSURL *fileURL in urlsToDelete) {
            
            [_fileManger removeItemAtURL:fileURL error:nil];
        }
        
        // If our remaining disk cache exceeds a configured maximum size, perform a second
        // size-based cleanup pass.  We delete the oldest files first.
        if (self.maxCacheSize > 0 && currentCacheSize > self.maxCacheSize) {
            // Target half of our maximum cache size for this cleanup pass.
            const NSUInteger desiredCacheSize = self.maxCacheSize / 2;
            
            // Sort the remaining cache files by their last modification time (oldest first).
            NSArray *sortedFiles = [cacheFiles keysSortedByValueWithOptions:NSSortConcurrent
                                                            usingComparator:^NSComparisonResult(id obj1, id obj2) {
                                                                return [obj1[NSURLContentModificationDateKey] compare:obj2[NSURLContentModificationDateKey]];
                                                            }];
            
            // Delete files until we fall below our desired cache size.
            for (NSURL *fileURL in sortedFiles) {
                if ([_fileManger removeItemAtURL:fileURL error:nil]) {
                    NSDictionary *resourceValues = cacheFiles[fileURL];
                    NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
                    currentCacheSize -= [totalAllocatedSize unsignedIntegerValue];
                    
                    if (currentCacheSize < desiredCacheSize) {
                        break;
                    }
                }
            }
        }
        
        
        
    });
}


- (NSUInteger)yj_cacheFileSize {

    __block NSUInteger size = 0;
    dispatch_async(_ioQueue, ^{
       
        NSDirectoryEnumerator *fileEnumerator = [_fileManger enumeratorAtPath:self.disCachePath];
        
        for (NSString *fileName in fileEnumerator) {
            
            NSString *filePath = [self.disCachePath stringByAppendingPathComponent:fileName];
            NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
            size += [fileAttributes fileSize];
        }
        
    });

    return size;
}


@end
