#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
@interface AEFeed : NSObject
+ (NSArray *)filter:(NSArray *)items;
@end
@interface AEPlayback : NSObject
+ (NSArray *)rankRenditions:(NSArray *)models;
+ (double)rate:(double)requested;
@end
@interface AEInterface : NSObject
+ (void)apply:(UIView *)view module:(NSString *)module option:(NSString *)option;
+ (void)applyButton:(UIView *)view;
+ (void)revealProgress:(UIView *)view;
@end
@interface AESave : NSObject
// Export only a user-selected, owned local original. No URL rewriting, DRM bypass or scraping.
+ (void)exportLocalOriginal:(NSURL *)url userOwnsOriginal:(BOOL)owns completion:(void (^)(BOOL))completion;
@end
NS_ASSUME_NONNULL_END
