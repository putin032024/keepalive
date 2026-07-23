# Rootless (Dopamine / RootHide) — giống HTCam
TARGET := iphone:clang:latest:14.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = SpringBoard
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = KeepAlive

KeepAlive_FILES = Tweak.x KAConfig.m
KeepAlive_CFLAGS = -fobjc-arc -Wno-unused-variable -Wno-deprecated-declarations -Wno-unguarded-availability-new
# Không link private frameworks (Xcode SDK CI không có FrontBoard)
# Dùng %c() / runtime — giống nhiều tweak SpringBoard
KeepAlive_FRAMEWORKS = UIKit Foundation UserNotifications CoreGraphics
KeepAlive_ARCHS = arm64
KeepAlive_LOGOS_DEFAULT_GENERATOR = internal

include $(THEOS_MAKE_PATH)/tweak.mk

# Prefs tắt trên CI (Xcode SDK không có Preferences.framework private)
# Bật/tắt bằng hold icon → Bật KeepAlive

after-install::
	install.exec "sbreload || killall -9 SpringBoard"
