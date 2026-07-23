TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard

ifeq ($(SCHEME),rootful)
else ifeq ($(SCHEME),roothide)
  THEOS_PACKAGE_SCHEME = roothide
else
  THEOS_PACKAGE_SCHEME ?= rootless
endif

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = KeepAlive

KeepAlive_FILES = Tweak.x KAConfig.m
KeepAlive_CFLAGS = -fobjc-arc -Wno-unused-variable -Wno-deprecated-declarations
KeepAlive_FRAMEWORKS = UIKit Foundation UserNotifications CoreGraphics
KeepAlive_PRIVATE_FRAMEWORKS = FrontBoard FrontBoardServices BackBoardServices
KeepAlive_LOGOS_DEFAULT_GENERATOR = internal

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "sbreload || killall -9 SpringBoard"
