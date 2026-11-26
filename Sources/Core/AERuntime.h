#import <Foundation/Foundation.h>
#import <objc/runtime.h>
NS_ASSUME_NONNULL_BEGIN
@interface AERuntime : NSObject
+ (instancetype)shared;
@property(nonatomic, readonly) NSString *hostVersion;
- (BOOL)mayInstallAdapters;
- (BOOL)probeClass:(NSString *)name selector:(NSString *)selector types:(NSArray<NSString *> *)types module:(NSString *)module;
- (BOOL)active:(NSString *)module option:(NSString *)option;
- (void)disable:(NSString *)module;
- (NSDictionary *)status;
@end
FOUNDATION_EXPORT id _Nullable AEObject(id _Nullable obj, NSString *selector);
FOUNDATION_EXPORT BOOL AEBool(id _Nullable obj, NSString *selector);
NS_ASSUME_NONNULL_END
