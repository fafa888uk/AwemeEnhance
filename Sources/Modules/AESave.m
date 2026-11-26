#import "AEModules.h"
#import "Core/AEConfig.h"
#import "Core/AELog.h"
#import <Photos/Photos.h>
@implementation AESave
+ (void)exportLocalOriginal:(NSURL *)url userOwnsOriginal:(BOOL)owns completion:(void (^)(BOOL))completion {
    if (!owns || ![AEConfig.shared flag:@"enabled"] || ![AEConfig.shared flag:@"saveOriginal"] || !url.isFileURL || ![[NSFileManager defaultManager] fileExistsAtPath:url.path]) { completion(NO); return; }
    // Never call Photos in a host missing its usage description (iOS would terminate it).
    if (![[NSBundle.mainBundle objectForInfoDictionaryKey:@"NSPhotoLibraryAddUsageDescription"] length]) { completion(NO); return; }
    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:^(PHAuthorizationStatus status) {
        if (status!=PHAuthorizationStatusAuthorized && status!=PHAuthorizationStatusLimited) { dispatch_async(dispatch_get_main_queue(), ^{ completion(NO); }); return; }
        [PHPhotoLibrary.sharedPhotoLibrary performChanges:^{ [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url]; } completionHandler:^(BOOL success,NSError *error) {
            if (!success) [AELog record:AEEventExportFailure module:@"save"];
            dispatch_async(dispatch_get_main_queue(), ^{ completion(success); });
        }];
    }];
}
@end
