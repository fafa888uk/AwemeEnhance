#import <Foundation/Foundation.h>
typedef NS_ENUM(NSInteger, AEEvent) { AEEventProbeOK, AEEventProbeMissing, AEEventConflict, AEEventModuleDisabled, AEEventReminderFailure, AEEventStorageFailure, AEEventExportFailure };
@interface AELog : NSObject
+ (void)record:(AEEvent)event module:(NSString *)module;
+ (NSArray<NSDictionary *> *)entries;
+ (void)clear;
@end
