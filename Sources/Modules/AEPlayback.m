#import "AEModules.h"
#import "Core/AEConfig.h"
#import "Core/AERuntime.h"
#import "Core/AEPolicy.h"
@implementation AEPlayback
+ (double)rate:(double)requested {
    return [AERuntime.shared active:@"speed" option:@"customSpeed"] ? AEClampRate([[AEConfig.shared value:@"rate"] doubleValue]) : requested;
}
+ (NSArray *)rankRenditions:(NSArray *)models {
    if (![models isKindOfClass:NSArray.class] || ![AERuntime.shared active:@"quality" option:@"highestQuality"]) return models;
    // Prefer, do not force: preserve the full host-provided fallback ladder and never fabricate URLs.
    // This assumes the host's candidate list is usable. Device/codec suitability still needs real testing.
    return [models sortedArrayUsingComparator:^NSComparisonResult(id a,id b) {
        id av=AEObject(a,@"bitrate"), bv=AEObject(b,@"bitrate");
        if (![av isKindOfClass:NSNumber.class] || ![bv isKindOfClass:NSNumber.class] || !AEObject(a,@"playAddr") || !AEObject(b,@"playAddr")) return NSOrderedSame;
        double x=[av doubleValue], y=[bv doubleValue];
        if (!isfinite(x) || !isfinite(y) || x<=0 || y<=0) return NSOrderedSame;
        return x>y ? NSOrderedAscending : x<y ? NSOrderedDescending : NSOrderedSame;
    }];
}
@end
