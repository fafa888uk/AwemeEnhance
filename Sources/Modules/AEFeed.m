#import "AEModules.h"
#import "Core/AEConfig.h"
#import "Core/AERuntime.h"
#import "Core/AEPolicy.h"
@implementation AEFeed
+ (NSArray *)filter:(NSArray *)items {
    if (![items isKindOfClass:NSArray.class]) return items;
    AEConfig *c=AEConfig.shared; BOOL enabled=[AERuntime.shared active:@"feed" option:@"enabled"];
    if (!enabled) return items;
    NSMutableArray *out=[NSMutableArray arrayWithCapacity:items.count];
    Class model=NSClassFromString(@"AWEAwemeModel");
    for (id item in items) {
        if (!model || ![item isKindOfClass:model]) { [out addObject:item]; continue; }
        // Scope to recommendation items; never remove search, profile, contacts or inbox data.
        if (![AEObject(item,@"referString") isEqual:@"homepage_hot"]) { [out addObject:item]; continue; }
        BOOL keyword=NO; id text=AEObject(item,@"descriptionString");
        if ([c flag:@"filterKeywords"] && [text isKindOfClass:NSString.class])
            for (NSString *word in [c value:@"keywords"]) if ([text rangeOfString:word options:NSCaseInsensitiveSearch].location!=NSNotFound) { keyword=YES; break; }
        if (!AEFilterItem(enabled,AEBool(item,@"isAds"),AEObject(item,@"cellRoom")!=nil || AEBool(item,@"isLive"),keyword,[c flag:@"filterAds"],[c flag:@"filterLive"],[c flag:@"filterKeywords"])) [out addObject:item];
    }
    return [out copy];
}
@end
