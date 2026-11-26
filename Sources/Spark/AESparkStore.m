#import "AESpark.h"
#import "Core/AELog.h"
@interface AESparkStore ()
@property(nonatomic, strong) NSURL *url;
@property(nonatomic, strong) NSMutableArray *people;
@property(nonatomic, strong) NSMutableArray *records;
@property(nonatomic, strong) NSDate *lastPrepared;
@property(nonatomic) BOOL writable;
@end
@implementation AESparkStore
+ (instancetype)shared { static AESparkStore *s; static dispatch_once_t once; dispatch_once(&once, ^{ s=[self new]; }); return s; }
- (BOOL)validFriend:(NSDictionary *)f {
    if (![f isKindOfClass:NSDictionary.class] || f.count!=6) return NO;
    if (![f[@"id"] isKindOfClass:NSString.class] || ![[NSUUID alloc] initWithUUIDString:f[@"id"]]) return NO;
    for (NSString *key in @[@"alias",@"message",@"timezone"]) if (![f[key] isKindOfClass:NSString.class] || ![f[key] length]) return NO;
    if ([f[@"alias"] length]>100 || [f[@"message"] length]>1000 || ![NSTimeZone timeZoneWithName:f[@"timezone"]]) return NO;
    return [f[@"minute"] isKindOfClass:NSNumber.class] && [f[@"minute"] integerValue]>=0 && [f[@"minute"] integerValue]<1440 && [f[@"enabled"] isKindOfClass:NSNumber.class];
}
- (instancetype)init {
    if ((self=[super init])) {
        NSURL *root=[NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
        root=[root URLByAppendingPathComponent:@"AwemeEnhance" isDirectory:YES];
        _writable=[NSFileManager.defaultManager createDirectoryAtURL:root withIntermediateDirectories:YES attributes:@{NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication} error:nil];
        [root setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
        _url=[root URLByAppendingPathComponent:@"spark.plist"]; _people=[NSMutableArray array]; _records=[NSMutableArray array];
        if ([NSFileManager.defaultManager fileExistsAtPath:_url.path]) {
            NSDictionary *state=[NSDictionary dictionaryWithContentsOfURL:_url];
            if (![state[@"schema"] isEqual:@1] || ![state[@"friends"] isKindOfClass:NSArray.class] || ![state[@"history"] isKindOfClass:NSArray.class]) _writable=NO;
            else {
                for (id f in state[@"friends"]) { if (![self validFriend:f]) { _writable=NO; break; } [_people addObject:f]; }
                for (id r in state[@"history"]) {
                    if (![r isKindOfClass:NSDictionary.class] || ![r[@"id"] isKindOfClass:NSString.class] || ![r[@"day"] isKindOfClass:NSString.class] || ![r[@"time"] isKindOfClass:NSDate.class] || ![@[@"prepared",@"manual-confirmed"] containsObject:r[@"status"]]) { _writable=NO; break; }
                    [_records addObject:r];
                }
                _lastPrepared=[state[@"lastPrepared"] isKindOfClass:NSDate.class] ? state[@"lastPrepared"] : nil;
            }
        }
        if (!_writable) [AELog record:AEEventStorageFailure module:@"spark"];
    } return self;
}
- (BOOL)persist {
    if (!self.writable) return NO;
    NSMutableDictionary *state=[@{@"schema":@1,@"friends":self.people,@"history":self.records} mutableCopy];
    if (self.lastPrepared) state[@"lastPrepared"]=self.lastPrepared;
    NSError *error=nil; NSData *data=[NSPropertyListSerialization dataWithPropertyList:state format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
    BOOL ok=data && [data writeToURL:self.url options:NSDataWritingAtomic | NSDataWritingFileProtectionCompleteUntilFirstUserAuthentication error:&error];
    if (!ok) { self.writable=NO; [AELog record:AEEventStorageFailure module:@"spark"]; } return ok;
}
- (NSArray *)friends { @synchronized(self) { return [self.people copy]; } }
- (NSArray *)history { @synchronized(self) { return [self.records copy]; } }
- (BOOL)saveFriend:(NSDictionary *)f {
    if (![self validFriend:f]) return NO;
    @synchronized(self) {
        NSUInteger index=[self.people indexOfObjectPassingTest:^BOOL(id obj,NSUInteger idx,BOOL *stop){ return [obj[@"id"] isEqual:f[@"id"]]; }];
        for (NSDictionary *other in self.people) if (![other[@"id"] isEqual:f[@"id"]] && [other[@"alias"] caseInsensitiveCompare:f[@"alias"]]==NSOrderedSame) return NO;
        if (index==NSNotFound && self.people.count>=32) return NO;
        if (index==NSNotFound) [self.people addObject:[f copy]]; else self.people[index]=[f copy]; return [self persist];
    }
}
- (BOOL)removeFriend:(NSString *)identifier { @synchronized(self) { NSIndexSet *set=[self.people indexesOfObjectsPassingTest:^BOOL(id f,NSUInteger i,BOOL *stop){ return [f[@"id"] isEqual:identifier]; }]; [self.people removeObjectsAtIndexes:set]; return [self persist]; } }
- (BOOL)handled:(NSString *)identifier day:(NSString *)day { @synchronized(self) { for (NSDictionary *r in self.records) if ([r[@"id"] isEqual:identifier] && [r[@"day"] isEqual:day]) return YES; return NO; } }
- (BOOL)prepare:(NSString *)identifier day:(NSString *)day now:(NSDate *)now {
    @synchronized(self) {
        if (!self.writable || [self handled:identifier day:day] || (self.lastPrepared && [now timeIntervalSinceDate:self.lastPrepared]<60)) return NO;
        BOOL found=NO; for (NSDictionary *f in self.people) if ([f[@"id"] isEqual:identifier] && [f[@"enabled"] boolValue]) found=YES;
        if (!found) return NO;
        [self.records addObject:@{@"id":identifier,@"day":day,@"status":@"prepared",@"time":now}]; self.lastPrepared=now;
        // Keep dedup keys for all retained days; no silently forgotten same-day record.
        NSDate *cutoff=[now dateByAddingTimeInterval:-400*86400.0];
        NSIndexSet *old=[self.records indexesOfObjectsPassingTest:^BOOL(id r,NSUInteger i,BOOL *stop){ return [r[@"time"] compare:cutoff]==NSOrderedAscending; }];
        [self.records removeObjectsAtIndexes:old]; return [self persist];
    }
}
- (BOOL)confirmManual:(NSString *)identifier day:(NSString *)day { @synchronized(self) {
    for (NSUInteger i=0;i<self.records.count;i++) { NSDictionary *r=self.records[i]; if ([r[@"id"] isEqual:identifier] && [r[@"day"] isEqual:day]) { NSMutableDictionary *copy=[r mutableCopy]; copy[@"status"]=@"manual-confirmed"; self.records[i]=copy; return [self persist]; } } return NO;
} }
- (BOOL)reset { @synchronized(self) { [self.people removeAllObjects]; [self.records removeAllObjects]; self.lastPrepared=nil; self.writable=YES; return [self persist]; } }
@end
