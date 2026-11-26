#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface AESparkStore : NSObject
+ (instancetype)shared;
- (NSArray<NSDictionary *> *)friends;
- (NSArray<NSDictionary *> *)history;
- (BOOL)saveFriend:(NSDictionary *)friendConfig;
- (BOOL)removeFriend:(NSString *)identifier;
- (BOOL)handled:(NSString *)identifier day:(NSString *)day;
- (BOOL)prepare:(NSString *)identifier day:(NSString *)day now:(NSDate *)now;
- (BOOL)confirmManual:(NSString *)identifier day:(NSString *)day;
- (BOOL)reset;
@end
@interface AESparkScheduler : NSObject
+ (instancetype)shared;
- (void)start;
- (void)reconcile;
- (NSArray<NSDictionary *> *)dueFriends;
- (NSString *)dayForFriend:(NSDictionary *)friendConfig;
@end
NS_ASSUME_NONNULL_END
