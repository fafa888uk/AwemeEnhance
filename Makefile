ARCHS = arm64
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = Aweme
DEBUG = 0
FINALPACKAGE = 1
export THEOS_STRICT_LOGOS = 1
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = AwemeEnhance
AwemeEnhance_FILES = Sources/Tweak.xm Sources/Core/AEConfig.m Sources/Core/AELog.m Sources/Core/AERuntime.m Sources/Core/AEPolicy.c Sources/Modules/AEFeed.m Sources/Modules/AEPlayback.m Sources/Modules/AEInterface.m Sources/Modules/AESave.m Sources/Spark/AESparkStore.m Sources/Spark/AESparkScheduler.m Sources/Settings/AESettingsController.m
AwemeEnhance_CFLAGS = -Wall -Wextra -I$(THEOS_PROJECT_DIR)/Sources -Wno-unused-parameter
AwemeEnhance_OBJCFLAGS = -fobjc-arc
AwemeEnhance_FRAMEWORKS = UIKit Foundation AVFoundation Photos UserNotifications CoreMedia UniformTypeIdentifiers
AwemeEnhance_LOGOS_DEFAULT_GENERATOR = internal
include $(THEOS_MAKE_PATH)/tweak.mk
