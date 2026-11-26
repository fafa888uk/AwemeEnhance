#import "AEModules.h"
#import "Core/AEConfig.h"
#import "Core/AERuntime.h"
#import "Core/AEPolicy.h"
#import <objc/runtime.h>
static char AEViewSnapshot;
@implementation AEInterface
+ (void)setView:(UIView *)v hidden:(BOOL)hide opacity:(CGFloat)opacity modifying:(BOOL)modifying {
    if (![NSThread isMainThread] || ![v isKindOfClass:UIView.class]) return;
    NSDictionary *old=objc_getAssociatedObject(v,&AEViewSnapshot);
    if (modifying) {
        if (!old) { old=@{@"hidden":@(v.hidden),@"alpha":@(v.alpha)}; objc_setAssociatedObject(v,&AEViewSnapshot,old,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
        v.hidden=hide; v.alpha=opacity;
    } else if (old) {
        v.hidden=[old[@"hidden"] boolValue]; v.alpha=[old[@"alpha"] doubleValue]; objc_setAssociatedObject(v,&AEViewSnapshot,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
+ (void)apply:(UIView *)v module:(NSString *)module option:(NSString *)option {
    BOOL hide=[AERuntime.shared active:module option:option];
    BOOL alpha=[AERuntime.shared active:module option:@"customOpacity"];
    [self setView:v hidden:hide opacity:alpha ? AEClampOpacity([[AEConfig.shared value:@"opacity"] doubleValue]) : 1 modifying:hide || alpha];
}
+ (void)applyButton:(UIView *)v {
    if (![v isKindOfClass:UIView.class]) return;
    BOOL hide=[AERuntime.shared active:@"buttons" option:@"hideButtons"] && [[AEConfig.shared value:@"hiddenButtons"] containsObject:v.accessibilityLabel ?: @""];
    [self setView:v hidden:YES opacity:1 modifying:hide];
}
+ (void)revealProgress:(UIView *)v {
    // Use the host's native slider and seek delegate. Do not guess a private seek selector.
    BOOL enabled=[AERuntime.shared active:@"progress" option:@"progress"];
    [self setView:v hidden:NO opacity:1 modifying:enabled];
}
@end
