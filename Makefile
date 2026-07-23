TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard

# Dopamine rootless default
ifeq ($(SCHEME),rootful)
else ifeq ($(SCHEME),roothide)
  THEOS_PACKAGE_SCHEME = roothide
else
  THEOS_PACKAGE_SCHEME ?= rootless
endif

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ForceBanner

ForceBanner_FILES = Tweak.x
ForceBanner_CFLAGS = -fobjc-arc -Wno-unused-variable -Wno-deprecated-declarations
ForceBanner_FRAMEWORKS = UIKit Foundation UserNotifications
ForceBanner_LOGOS_DEFAULT_GENERATOR = internal

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "sbreload || killall -9 SpringBoard"
