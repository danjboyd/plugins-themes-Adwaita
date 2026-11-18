# Copyright (C) 2025-2026 Daniel Boyd
#
# This file is part of the GNUstep Adwaita theme.
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; see the file COPYING.LIB.
# If not, see <http://www.gnu.org/licenses/>.

ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
endif
ifeq ($(GNUSTEP_MAKEFILES),)
 $(error You need to set GNUSTEP_MAKEFILES before compiling!)
endif

include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = ThemeDemo
ThemeDemo_APPLICATION_ICON =
ThemeDemo_PRINCIPAL_CLASS = NSApplication

ThemeDemo_OBJC_FILES = \
	main.m \
	AppController.m \
	ThemeDemoTableDataSource.m

ThemeDemo_HEADER_FILES = \
	AppController.h \
	ThemeDemoTableDataSource.h

ThemeDemo_RESOURCE_FILES = ThemeDemoInfo.plist

# The Theme Settings panel (ThemeDemo > Theme Settings...) uses
# gnustep-themes' ThemeSettingsKit and ThemeSettingsUI. It's built when
# their headers are found in the GNUstep header path, or set
# THEME_SETTINGS=yes (or no) to choose. THEME_SETTINGS_PREFIX names a tree
# that has them instead (as an unpacked package: usr/GNUstep/System/...).
ifneq ($(THEME_SETTINGS_PREFIX),)
 THEME_SETTINGS_HEADERS := $(THEME_SETTINGS_PREFIX)/Library/Headers
 THEME_SETTINGS_LIBS := $(THEME_SETTINGS_PREFIX)/Library/Libraries
endif
ifeq ($(THEME_SETTINGS),)
 THEME_SETTINGS := $(if $(wildcard $(THEME_SETTINGS_HEADERS)/ThemeSettingsUI/ThemeSettingsUI.h $(GNUSTEP_SYSTEM_HEADERS)/ThemeSettingsUI/ThemeSettingsUI.h $(GNUSTEP_LOCAL_HEADERS)/ThemeSettingsUI/ThemeSettingsUI.h $(GNUSTEP_USER_HEADERS)/ThemeSettingsUI/ThemeSettingsUI.h),yes,no)
endif
ifeq ($(THEME_SETTINGS),yes)
 ThemeDemo_OBJC_FILES += ThemeDemoSettingsPanel.m
 ThemeDemo_HEADER_FILES += ThemeDemoSettingsPanel.h
 ADDITIONAL_OBJCFLAGS += -DTHEMEDEMO_THEME_SETTINGS=1
 ifneq ($(THEME_SETTINGS_HEADERS),)
  ADDITIONAL_INCLUDE_DIRS += -I$(THEME_SETTINGS_HEADERS)
  ADDITIONAL_LIB_DIRS += -L$(THEME_SETTINGS_LIBS)
 endif
 ThemeDemo_GUI_LIBS += -lThemeSettingsUI -lThemeSettingsKit
endif

ADDITIONAL_OBJCFLAGS += -Wno-import

include $(GNUSTEP_MAKEFILES)/application.make
