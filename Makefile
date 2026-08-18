TARGET := iphone:clang:latest:arm64
INSTALL_TARGET_PROCESSES = SpringBoard

ARCHS = arm64

OBJC_FILES = src/GetWiFi.mm src/getwifi.m

PROJECT_NAME = GetWiFi

THEOS ?= /opt/theos
THEOS_PACKAGE_DIR_NAME ?= debs

include $(THEOS)/makefiles/common.mk

TOOL_NAME = getwifi

$(TOOL_NAME)_FILES = src/getwifi.m
$(TOOL_NAME)_CFLAGS = -fobjc-arc -F$(THEOS)/vendor/lib
$(TOOL_NAME)_FRAMEWORKS = Foundation MobileWiFi

BUNDLE_NAME = GetWiFi

$(BUNDLE_NAME)_FILES = src/GetWiFi.mm
$(BUNDLE_NAME)_CFLAGS = -fobjc-arc
$(BUNDLE_NAME)_FRAMEWORKS = UIKit Foundation MobileWiFi
$(BUNDLE_NAME)_PRIVATE_FRAMEWORKS = MobileWiFi
$(BUNDLE_NAME)_INSTALL_PATH = /Library/Loader/SBPlugins

include $(THEOS_MAKEFILTERS)/aggregate.mk

internal-install::
	install.exec "killall -9 SpringBoard"
