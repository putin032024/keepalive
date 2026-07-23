TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e

ifeq ($(SCHEME),rootful)
else ifeq ($(SCHEME),roothide)
  THEOS_PACKAGE_SCHEME = roothide
else
  THEOS_PACKAGE_SCHEME ?= rootless
endif

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = ForceBannerPrefs

ForceBannerPrefs_FILES = AARootListController.m
ForceBannerPrefs_FRAMEWORKS = UIKit
ForceBannerPrefs_PRIVATE_FRAMEWORKS = Preferences
ForceBannerPrefs_INSTALL_PATH = /Library/PreferenceBundles
ForceBannerPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/ForceBanner.plist$(ECHO_END)
