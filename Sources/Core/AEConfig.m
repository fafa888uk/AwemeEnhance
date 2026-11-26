#import "AEConfig.h"
#import "AEPolicy.h"
#import <CoreFoundation/CoreFoundation.h>
NSNotificationName const AEConfigChanged = @"io.github.awemeenhance.config.changed";
@interface AEConfig ()
@property(nonatomic, strong) NSUserDefaults *store;
@end
@implementation AEConfig
+ (instancetype)shared { static AEConfig *s; static dispatch_once_t once; dispatch_once(&once, ^{ s = [self new]; }); return s; }
+ (NSDictionary *)defaults {
    return @{@"enabled":@NO, @"experimentalAdapters":@NO, @"filterAds":@NO,
             @"filterLive":@NO, @"filterKeywords":@NO, @"keywords":@[],
             @"highestQuality":@NO, @"customSpeed":@NO, @"rate":@1.0,
             @"progress":@NO, @"hideTop":@NO, @"hideBottom":@NO,
             @"hideButtons":@NO, @"hiddenButtons":@[@"分享",@"合拍"],
             @"customOpacity":@NO, @"opacity":@1.0, @"saveOriginal":@NO,
             @"sparkEnabled":@NO, @"sparkConsent":@NO};
}
- (instancetype)init {
    if ((self = [super init])) { _store = [[NSUserDefaults alloc] initWithSuiteName:@"io.github.awemeenhance.settings"]; [_store registerDefaults:self.class.defaults]; }
    return self;
}
- (id)value:(NSString *)key { @synchronized(self) { return [self.store objectForKey:key] ?: self.class.defaults[key]; } }
- (BOOL)flag:(NSString *)key { return [[self value:key] isKindOfClass:NSNumber.class] && [[self value:key] boolValue]; }
- (BOOL)valid:(id)v key:(NSString *)key {
    id d = self.class.defaults[key]; if (!d) return NO;
    if ([d isKindOfClass:NSArray.class]) {
        if (![v isKindOfClass:NSArray.class] || [v count] > 100) return NO;
        for (id s in v) if (![s isKindOfClass:NSString.class] || [s length] == 0 || [s length] > 200) return NO;
        return YES;
    }
    if (![v isKindOfClass:NSNumber.class]) return NO;
    if ([key isEqual:@"rate"]) return AEClampRate([v doubleValue]) == [v doubleValue];
    if ([key isEqual:@"opacity"]) return AEClampOpacity([v doubleValue]) == [v doubleValue];
    return CFGetTypeID((__bridge CFTypeRef)v) == CFBooleanGetTypeID();
}
- (void)notify { dispatch_async(dispatch_get_main_queue(), ^{ [[NSNotificationCenter defaultCenter] postNotificationName:AEConfigChanged object:self]; }); }
- (BOOL)setValue:(id)v forOption:(NSString *)key {
    if (![self valid:v key:key]) return NO;
    @synchronized(self) { [self.store setObject:v forKey:key]; } [self notify]; return YES;
}
- (NSDictionary *)exportConfiguration {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    for (NSString *key in self.class.defaults) if (![key hasPrefix:@"spark"]) out[key] = [self value:key];
    return @{@"schema":@1,@"options":out};
}
- (BOOL)importConfiguration:(NSDictionary *)configuration {
    if (![configuration isKindOfClass:NSDictionary.class] || ![configuration[@"schema"] isEqual:@1]) return NO;
    NSDictionary *options = configuration[@"options"];
    if (![options isKindOfClass:NSDictionary.class]) return NO;
    for (NSString *key in options) if (![key isKindOfClass:NSString.class] || [key hasPrefix:@"spark"] || ![self valid:options[key] key:key]) return NO;
    @synchronized(self) { for (NSString *key in options) [self.store setObject:options[key] forKey:key]; }
    [self notify]; return YES;
}
- (void)reset { @synchronized(self) { for (NSString *key in self.class.defaults) [self.store removeObjectForKey:key]; } [self notify]; }
@end
