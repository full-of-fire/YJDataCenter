//
//  YJCache.h
//  YJCache
//
//  Created by yj on 17/3/20.
//  Copyright © 2017年 yj. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface YJCache : NSObject

@property (assign,nonatomic) NSUInteger maxMemoryCountList;
@property (assign,nonatomic) NSUInteger maxCacheAge;
@property (assign,nonatomic) NSUInteger maxCacheSize;
@property (assign,nonatomic) BOOL shouldCahceInMemory;  // 默认为YES
+ (instancetype)sharedCache;

- (instancetype)initWithName:(NSString*)name;
- (instancetype)initWithName:(NSString*)name disCacheDirectory:(NSString*)directory;

- (void)yj_cacheObject:(id<NSCoding>)object forKey:(NSString*)key;

- (id<NSCoding>)yj_objectForKey:(NSString*)key;
- (void)yj_objectForKey:(NSString*)key complteHanlder:(void(^)(id<NSCoding>object))complteHanlder;

- (void)yj_removeObjectForKey:(NSString*)key;
- (void)yj_removeAllObjects;

- (NSUInteger)yj_cacheFileSize;

@end
