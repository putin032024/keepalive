# Build dylib inject cho TrollFools (arm64 + arm64e)
TARGET := iphone:clang:14.5:14.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = Zalo2KeepAlive

Zalo2KeepAlive_FILES = Zalo2KeepAlive.m
Zalo2KeepAlive_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unguarded-availability-new
Zalo2KeepAlive_FRAMEWORKS = UIKit Foundation AVFoundation UserNotifications
Zalo2KeepAlive_INSTALL_PATH = /usr/local/lib
Zalo2KeepAlive_LIBRARIES =

include $(THEOS_MAKE_PATH)/library.mk

internal-stage::
	@mkdir -p $(THEOS_PROJECT_DIR)/packages
	@DY=$$(find .theos/obj -name 'Zalo2KeepAlive.dylib' | head -1); \
	if [ -n "$$DY" ]; then \
	  cp "$$DY" $(THEOS_PROJECT_DIR)/packages/Zalo2KeepAlive.dylib; \
	  cd $(THEOS_PROJECT_DIR)/packages && zip -j Zalo2KeepAlive-TrollFools.zip Zalo2KeepAlive.dylib; \
	  echo ">>> packages/Zalo2KeepAlive.dylib + zip ready"; \
	  lipo -info Zalo2KeepAlive.dylib 2>/dev/null || true; \
	fi
