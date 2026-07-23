TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = AlwaysAlivePrefs

AlwaysAlivePrefs_FILES = AARootListController.m
AlwaysAlivePrefs_FRAMEWORKS = UIKit
AlwaysAlivePrefs_PRIVATE_FRAMEWORKS = Preferences
AlwaysAlivePrefs_INSTALL_PATH = /Library/PreferenceBundles
AlwaysAlivePrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/KeepAlive.plist$(ECHO_END)
