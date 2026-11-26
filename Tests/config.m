#import <Foundation/Foundation.h>
#import "Core/AEConfig.h"
#import "Core/AELog.h"
int main(void) { @autoreleasepool {
    AEConfig *c=AEConfig.shared; [c reset];
    NSCAssert(![c flag:@"enabled"] && ![c flag:@"sparkConsent"], @"defaults off");
    NSCAssert(![c setValue:@3.5 forOption:@"rate"], @"rate bound");
    NSCAssert(![c setValue:@"true" forOption:@"enabled"], @"type guard");
    NSCAssert([c setValue:@1.5 forOption:@"rate"], @"valid rate");
    NSCAssert(![c importConfiguration:@{@"schema":@1,@"options":@{@"sparkConsent":@YES}}], @"consent cannot be imported");
    NSCAssert(![c importConfiguration:@{@"schema":@1,@"options":@{@"unknown":@YES}}], @"unknown keys fail closed");
    NSCAssert([c importConfiguration:@{@"schema":@1,@"options":@{@"rate":@2.0}}], @"valid import");
    NSCAssert([c.exportConfiguration[@"options"] objectForKey:@"sparkConsent"]==nil, @"export excludes private config");
    NSCAssert(![c setValue:@[@42] forOption:@"keywords"], @"keyword type");
    for (int i=0;i<250;i++) [AELog record:AEEventProbeOK module:@"feed"];
    NSCAssert(AELog.entries.count==200, @"bounded privacy-safe log");
    [c reset]; puts("configuration: all assertions passed");
} return 0; }
