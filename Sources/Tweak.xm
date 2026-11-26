#import <UIKit/UIKit.h>
#import "Core/AERuntime.h"
#import "Modules/AEModules.h"
#import "Settings/AESettingsController.h"
#import "Spark/AESpark.h"

@interface AEHostFeed : NSObject @end
@interface AEHostPlayer : NSObject @end
@interface AEHostVideo : NSObject @end
@interface AEHostTop : UIView @end
@interface AEHostBottom : UIView @end
@interface AEHostButton : UIView @end
@interface AEHostProgress : UIView @end

%group Entry
%hook UIWindow
- (void)becomeKeyWindow { %orig; AEInstallSettingsGesture(self); }
%end
%end

%group Feed
%hook AEHostFeed
- (id)transferAwemeListIfNeededWithArray:(id)array isInitFetch:(BOOL)initial {
    id result=%orig(array, initial); // Call the host exactly once, outside our exception boundary.
    @try { return [AEFeed filter:result]; } @catch (__unused NSException *e) { [AERuntime.shared disable:@"feed"]; return result; }
}
%end
%end
%group Speed
%hook AEHostPlayer
- (void)setVideoControllerPlaybackRate:(double)rate {
    double value=rate;
    @try { value=[AEPlayback rate:rate]; } @catch (__unused NSException *e) { [AERuntime.shared disable:@"speed"]; }
    %orig(value);
}
%end
%end
%group Quality
%hook AEHostVideo
- (id)bitrateModels {
    id result=%orig;
    @try { return [AEPlayback rankRenditions:result]; } @catch (__unused NSException *e) { [AERuntime.shared disable:@"quality"]; return result; }
}
%end
%end
%group Top
%hook AEHostTop
- (void)layoutSubviews {
    %orig;
    @try { [AEInterface apply:self module:@"top" option:@"hideTop"]; } @catch (__unused NSException *e) { [AERuntime.shared disable:@"top"]; }
}
%end
%end
%group Bottom
%hook AEHostBottom
- (void)layoutSubviews {
    %orig;
    @try { [AEInterface apply:self module:@"bottom" option:@"hideBottom"]; } @catch (__unused NSException *e) { [AERuntime.shared disable:@"bottom"]; }
}
%end
%end
%group Buttons
%hook AEHostButton
- (void)layoutSubviews {
    %orig;
    @try { [AEInterface applyButton:self]; } @catch (__unused NSException *e) { [AERuntime.shared disable:@"buttons"]; }
}
%end
%end
%group Progress
%hook AEHostProgress
- (void)layoutSubviews {
    %orig;
    @try { [AEInterface revealProgress:self]; } @catch (__unused NSException *e) { [AERuntime.shared disable:@"progress"]; }
}
%end
%end

static void AEStart(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [AESparkScheduler.shared start];
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes)
            if ([scene isKindOfClass:UIWindowScene.class]) for (UIWindow *w in ((UIWindowScene *)scene).windows) AEInstallSettingsGesture(w);
        AERuntime *r=AERuntime.shared;
        if (![r mayInstallAdapters]) return;
        if ([r probeClass:@"AWEHotListDataController" selector:@"transferAwemeListIfNeededWithArray:isInitFetch:" types:@[@"@",@"@",@":",@"@",@"B"] module:@"feed"]) { %init(Feed, AEHostFeed=NSClassFromString(@"AWEHotListDataController")); }
        // 41.x has several player stacks. Only install the first ABI-matching adapter, not arbitrary selectors.
        for (NSString *name in @[@"AWEDPlayerFeedPlayerViewController",@"AWEDPlayerViewController_Merge",@"AWEAwemePlayVideoViewController"])
            if ([r probeClass:name selector:@"setVideoControllerPlaybackRate:" types:@[@"v",@"@",@":",@"d"] module:@"speed"]) { %init(Speed, AEHostPlayer=NSClassFromString(name)); break; }
        if ([r probeClass:@"AWEVideoModel" selector:@"bitrateModels" types:@[@"@",@"@",@":"] module:@"quality"]) { %init(Quality, AEHostVideo=NSClassFromString(@"AWEVideoModel")); }
        if ([r probeClass:@"AWEFeedTopBarContainer" selector:@"layoutSubviews" types:@[@"v",@"@",@":"] module:@"top"]) { %init(Top, AEHostTop=NSClassFromString(@"AWEFeedTopBarContainer")); }
        if ([r probeClass:@"AWENormalModeTabBar" selector:@"layoutSubviews" types:@[@"v",@"@",@":"] module:@"bottom"]) { %init(Bottom, AEHostBottom=NSClassFromString(@"AWENormalModeTabBar")); }
        if ([r probeClass:@"AWEFeedVideoButton" selector:@"layoutSubviews" types:@[@"v",@"@",@":"] module:@"buttons"]) { %init(Buttons, AEHostButton=NSClassFromString(@"AWEFeedVideoButton")); }
        if ([r probeClass:@"AWEFeedProgressSlider" selector:@"layoutSubviews" types:@[@"v",@"@",@":"] module:@"progress"]) { %init(Progress, AEHostProgress=NSClassFromString(@"AWEFeedProgressSlider")); }
    });
}
%ctor {
    @autoreleasepool {
        if ([NSBundle.mainBundle.bundleIdentifier isEqual:@"com.ss.iphone.ugc.Aweme"]) {
            %init(Entry);
            [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *n){ AEStart(); }];
            dispatch_async(dispatch_get_main_queue(), ^{ if (UIApplication.sharedApplication.applicationState!=UIApplicationStateInactive) AEStart(); });
        }
    }
}
