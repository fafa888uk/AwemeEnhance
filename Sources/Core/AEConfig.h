#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSNotificationName const AEConfigChanged;
@interface AEConfig : NSObject
+ (instancetype)shared;
+ (NSDictionary *)defaults;
- (BOOL)flag:(NSString *)key;
- (id)value:(NSString *)key;
- (BOOL)setValue:(id)value forOption:(NSString *)key;
- (NSDictionary *)exportConfiguration; // Deliberately excludes friends and message contents.
- (BOOL)importConfiguration:(NSDictionary *)configuration;
- (void)reset;
@end
NS_ASSUME_NONNULL_END
