TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard

# Dopamine / rootless (default). Rootful CI: make package THEOS_PACKAGE_SCHEME=
# or unset THEOS_PACKAGE_SCHEME
ifeq ($(SCHEME),rootful)
  # no package scheme
else
  THEOS_PACKAGE_SCHEME ?= rootless
endif

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AlwaysAlive

AlwaysAlive_FILES = Tweak.x TweakScene.x TweakNotifications.x TweakIcons.x AAConfig.m
AlwaysAlive_CFLAGS = -fobjc-arc -Wno-unused-variable -Wno-deprecated-declarations
AlwaysAlive_FRAMEWORKS = UIKit Foundation UserNotifications CoreGraphics
AlwaysAlive_PRIVATE_FRAMEWORKS = FrontBoard FrontBoardServices BackBoardServices
AlwaysAlive_LOGOS_DEFAULT_GENERATOR = internal

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "sbreload || killall -9 SpringBoard"
