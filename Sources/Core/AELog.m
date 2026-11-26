#import "AELog.h"
@implementation AELog
static NSMutableArray *buffer;
+ (void)record:(AEEvent)event module:(NSString *)module {
    // No arbitrary exception/network/account text is accepted by the logger.
    NSSet *allowed = [NSSet setWithArray:@[@"feed",@"speed",@"quality",@"top",@"bottom",@"buttons",@"progress",@"spark",@"save",@"runtime"]];
    if (![allowed containsObject:module]) module = @"runtime";
    @synchronized(self) { if (!buffer) buffer = [NSMutableArray array]; [buffer addObject:@{@"time":@([[NSDate date] timeIntervalSince1970]),@"event":@(event),@"module":module}]; if (buffer.count > 200) [buffer removeObjectAtIndex:0]; }
}
+ (NSArray *)entries { @synchronized(self) { return [buffer copy] ?: @[]; } }
+ (void)clear { @synchronized(self) { [buffer removeAllObjects]; } }
@end
