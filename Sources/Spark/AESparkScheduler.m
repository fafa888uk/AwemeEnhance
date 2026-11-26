#import "AESpark.h"
#import "Core/AEConfig.h"
#import "Core/AEPolicy.h"
#import "Core/AELog.h"
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
@interface AESparkScheduler ()
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic) NSUInteger generation;
@end
@implementation AESparkScheduler
+ (instancetype)shared { static AESparkScheduler *s; static dispatch_once_t once; dispatch_once(&once, ^{ s=[self new]; }); return s; }
- (void)start {
    NSNotificationCenter *n=NSNotificationCenter.defaultCenter;
    [n addObserver:self selector:@selector(reconcile) name:AEConfigChanged object:nil];
    [n addObserver:self selector:@selector(reconcile) name:UIApplicationDidBecomeActiveNotification object:nil];
    [n addObserver:self selector:@selector(suspend) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [self reconcile];
}
- (void)suspend { [self.timer invalidate]; self.timer=nil; }
- (BOOL)authorized { return [AEConfig.shared flag:@"enabled"] && [AEConfig.shared flag:@"sparkEnabled"] && [AEConfig.shared flag:@"sparkConsent"]; }
- (NSCalendar *)calendar:(NSDictionary *)f { NSCalendar *c=[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian]; c.timeZone=[NSTimeZone timeZoneWithName:f[@"timezone"]] ?: NSTimeZone.localTimeZone; return c; }
- (NSString *)dayForFriend:(NSDictionary *)f {
    NSDateComponents *d=[[self calendar:f] components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:NSDate.date];
    return [NSString stringWithFormat:@"%04ld-%02ld-%02ld",(long)d.year,(long)d.month,(long)d.day];
}
- (NSArray *)dueFriends {
    NSMutableArray *out=[NSMutableArray array];
    for (NSDictionary *f in AESparkStore.shared.friends) {
        NSDateComponents *d=[[self calendar:f] components:NSCalendarUnitHour|NSCalendarUnitMinute fromDate:NSDate.date];
        if (AEDue([self authorized],YES,[f[@"enabled"] boolValue],(int)(d.hour*60+d.minute),[f[@"minute"] intValue],[AESparkStore.shared handled:f[@"id"] day:[self dayForFriend:f]])) [out addObject:f];
    } return out;
}
- (void)reconcile {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self reconcile]; }); return; }
    [self suspend]; NSUInteger generation=++self.generation;
    if ([self authorized] && UIApplication.sharedApplication.applicationState==UIApplicationStateActive)
        self.timer=[NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    UNUserNotificationCenter *center=UNUserNotificationCenter.currentNotificationCenter;
    [center getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> *requests) {
        NSMutableArray *ids=[NSMutableArray array]; for (UNNotificationRequest *r in requests) if ([r.identifier hasPrefix:@"ae.spark."]) [ids addObject:r.identifier];
        [center removePendingNotificationRequestsWithIdentifiers:ids];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation!=self.generation || ![self authorized]) return;
            [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (generation!=self.generation || ![self authorized]) return;
                    if (settings.authorizationStatus!=UNAuthorizationStatusAuthorized && settings.authorizationStatus!=UNAuthorizationStatusProvisional) return;
                    for (NSDictionary *f in AESparkStore.shared.friends) {
                        if (![f[@"enabled"] boolValue]) continue;
                        NSDateComponents *d=[NSDateComponents new]; d.calendar=[self calendar:f]; d.timeZone=d.calendar.timeZone; d.hour=[f[@"minute"] integerValue]/60; d.minute=[f[@"minute"] integerValue]%60;
                        UNMutableNotificationContent *content=[UNMutableNotificationContent new]; content.title=@"火花到期提醒"; content.body=@"打开增强设置检查待办；请在官方聊天界面核对好友并手动发送。"; content.sound=UNNotificationSound.defaultSound;
                        NSString *identifier=[NSString stringWithFormat:@"ae.spark.%lu.%@",(unsigned long)generation,f[@"id"]];
                        UNNotificationRequest *r=[UNNotificationRequest requestWithIdentifier:identifier content:content trigger:[UNCalendarNotificationTrigger triggerWithDateMatchingComponents:d repeats:YES]];
                        [center addNotificationRequest:r withCompletionHandler:^(NSError *error) {
                            if (error) [AELog record:AEEventReminderFailure module:@"spark"];
                            dispatch_async(dispatch_get_main_queue(), ^{ if (generation!=self.generation || ![self authorized]) [UNUserNotificationCenter.currentNotificationCenter removePendingNotificationRequestsWithIdentifiers:@[identifier]]; });
                        }];
                    }
                });
            }];
        });
    }];
    [self tick];
}
- (void)tick { [[NSNotificationCenter defaultCenter] postNotificationName:@"AESparkDueChanged" object:nil]; }
@end
