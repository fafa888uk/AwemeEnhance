#import "AEModules.h"
#import "Core/AEConfig.h"
#import "Core/AERuntime.h"
#import "Core/AEPolicy.h"
#include <math.h>
@implementation AEPlayback
+ (double)rate:(double)requested {
    return [AERuntime.shared active:@"speed" option:@"customSpeed"] ? AEClampRate([[AEConfig.shared value:@"rate"] doubleValue]) : requested;
}
+ (NSArray *)rankRenditions:(NSArray *)models {
    if (![models isKindOfClass:NSArray.class] || ![AERuntime.shared active:@"quality" option:@"highestQuality"]) return models;
    // Prefer, do not force: preserve the full host-provided fallback ladder and never fabricate URLs.
    // This assumes the host's candidate list is usable. Device/codec suitability still needs real testing.
    NSUInteger best=NSNotFound; double highest=0;
    for (NSUInteger i=0;i<models.count;i++) {
        id value=AEObject(models[i],@"bitrate");
        if (![value isKindOfClass:NSNumber.class] || !AEObject(models[i],@"playAddr")) continue;
        double bitrate=[value doubleValue];
        if (isfinite(bitrate) && bitrate>highest) { best=i; highest=bitrate; }
    }
    if (best==NSNotFound || best==0) return models;
    // Moving one candidate preserves the relative order of every original fallback.
    NSMutableArray *ranked=[models mutableCopy]; id preferred=ranked[best];
    [ranked removeObjectAtIndex:best]; [ranked insertObject:preferred atIndex:0]; return [ranked copy];
}
@end
