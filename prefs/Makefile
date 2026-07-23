TARGET := iphone:clang:latest:14.0
ARCHS = arm64
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = KeepAlivePrefs

KeepAlivePrefs_FILES = AARootListController.m
KeepAlivePrefs_FRAMEWORKS = UIKit
KeepAlivePrefs_PRIVATE_FRAMEWORKS = Preferences
KeepAlivePrefs_INSTALL_PATH = /Library/PreferenceBundles
KeepAlivePrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/KeepAlive.plist$(ECHO_END)
