THEOS_PACKAGE_SCHEME = rootless
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = HeliumDopamine
HeliumDopamine_FILES = Tweak.xm
HeliumDopamine_CFLAGS = -fobjc-arc
HeliumDopamine_FRAMEWORKS = UIKit Foundation
HeliumDopamine_PRIVATE_FRAMEWORKS = IOKit
include $(THEOS_MAKE_PATH)/tweak.mk
