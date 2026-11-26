#import "AERuntime.h"
#import "AEConfig.h"
#import "AELog.h"
#import <objc/message.h>
#import <mach-o/dyld.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
static BOOL AEType(Method m, unsigned int index, const char *expected) {
    char *t = index == 0 ? method_copyReturnType(m) : method_copyArgumentType(m, index - 1);
    BOOL yes = t && strcmp(t, expected) == 0; free(t); return yes;
}
id AEObject(id obj, NSString *s) {
    SEL sel = NSSelectorFromString(s); Method m = obj ? class_getInstanceMethod(object_getClass(obj),sel) : NULL;
    if (!m || method_getNumberOfArguments(m) != 2 || !AEType(m,0,"@")) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(obj,sel);
}
BOOL AEBool(id obj, NSString *s) {
    SEL sel = NSSelectorFromString(s); Method m = obj ? class_getInstanceMethod(object_getClass(obj),sel) : NULL;
    if (!m || method_getNumberOfArguments(m) != 2 || !AEType(m,0,"B")) return NO;
    return ((BOOL (*)(id, SEL))objc_msgSend)(obj,sel);
}
@interface AERuntime ()
@property(nonatomic, strong) NSMutableDictionary *states;
@end
@implementation AERuntime
+ (instancetype)shared { static AERuntime *s; static dispatch_once_t once; dispatch_once(&once, ^{ s=[self new]; s.states=[NSMutableDictionary dictionary]; }); return s; }
- (NSString *)hostVersion { return [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"unknown"; }
- (BOOL)conflict {
    for (uint32_t i=0; i<_dyld_image_count(); i++) {
        NSString *p = [@( _dyld_get_image_name(i) ?: "") lastPathComponent].lowercaseString;
        if ([p containsString:@"dyyy"] || [p containsString:@"dyplus"] || [p containsString:@"automessageplugin"]) return YES;
    } return NO;
}
- (BOOL)mayInstallAdapters {
    if (![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.ss.iphone.ugc.Aweme"]) return NO;
    if (![@[@"41.2.0",@"41.3.0"] containsObject:self.hostVersion]) return NO;
    if ([self conflict]) { [AELog record:AEEventConflict module:@"runtime"]; return NO; }
    // Both versions require explicit experimental opt-in. Presence is NOT device validation.
    return [AEConfig.shared flag:@"experimentalAdapters"];
}
- (BOOL)probeClass:(NSString *)name selector:(NSString *)s types:(NSArray<NSString *> *)types module:(NSString *)module {
    Class cls = NSClassFromString(name); Method m = cls ? class_getInstanceMethod(cls, NSSelectorFromString(s)) : NULL;
    BOOL ok = m && types.count >= 3 && method_getNumberOfArguments(m) == types.count-1;
    for (NSUInteger i=0; ok && i<types.count; ++i) ok = AEType(m,(unsigned int)i,types[i].UTF8String);
    // Refuse an IMP replaced by a different dylib, in addition to known conflict detection.
    if (ok) { Dl_info info = {0}; if (dladdr((const void *)method_getImplementation(m), &info) && info.dli_fname) {
        NSString *path = @(info.dli_fname);
        ok = [path hasPrefix:NSBundle.mainBundle.bundlePath] || [path hasPrefix:@"/System/Library/"];
    } else ok=NO; }
    @synchronized(self) { self.states[module] = ok ? @"candidate: ABI probe passed; device unverified" : @"disabled: missing interface / ABI / conflict"; }
    [AELog record:ok ? AEEventProbeOK : AEEventProbeMissing module:module]; return ok;
}
- (BOOL)active:(NSString *)module option:(NSString *)option {
    @synchronized(self) { return [self.states[module] hasPrefix:@"candidate"] && [AEConfig.shared flag:@"enabled"] && [AEConfig.shared flag:@"experimentalAdapters"] && [AEConfig.shared flag:option]; }
}
- (void)disable:(NSString *)module { @synchronized(self) { self.states[module]=@"disabled: exception until restart"; } [AELog record:AEEventModuleDisabled module:module]; }
- (NSDictionary *)status { @synchronized(self) { return [self.states copy]; } }
@end
