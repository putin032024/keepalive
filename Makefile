# Rootless deb — RootHide: convert bằng RootHide Patcher
# arm64e bắt buộc trên máy A12+ (RootHide báo: have arm64, need arm64e)
TARGET := iphone:clang:14.5:14.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = KeepAlive

KeepAlive_FILES = Tweak.x KAConfig.m
KeepAlive_CFLAGS = -fobjc-arc -Wno-unused-variable -Wno-deprecated-declarations -Wno-unguarded-availability-new
KeepAlive_FRAMEWORKS = UIKit Foundation UserNotifications CoreGraphics AVFoundation
KeepAlive_ARCHS = arm64 arm64e
KeepAlive_LOGOS_DEFAULT_GENERATOR = internal

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "sbreload || killall -9 SpringBoard"
