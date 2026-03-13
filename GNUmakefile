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

GIO_PACKAGES = gio-2.0 glib-2.0 gobject-2.0
GIO_CFLAGS = $(shell pkg-config --cflags $(GIO_PACKAGES))
GIO_LIBS = $(shell pkg-config --libs $(GIO_PACKAGES))

ADDITIONAL_OBJCFLAGS += -Wno-import $(GIO_CFLAGS)
ADDITIONAL_CFLAGS += $(GIO_CFLAGS)
ADDITIONAL_LDFLAGS += $(GIO_LIBS)

PACKAGE_NAME = Adwaita
BUNDLE_NAME = Adwaita
BUNDLE_EXTENSION = .theme
VERSION = 0.1.0-alpha1

Adwaita_PRINCIPAL_CLASS = GnomeTheme
Adwaita_INSTALL_DIR = $(GNUSTEP_LIBRARY)/Themes
Adwaita_RESOURCE_FILES = \
	Resources/Info-gnustep.plist \
	Resources/ThemeImages \
	Resources/ThemeTiles

Adwaita_OBJC_FILES = \
	Source/GnomeTheme.m \
	Source/Settings/GnomeThemeSettings.m \
	Source/Settings/GnomeThemeMetrics.m \
	Source/Rendering/GnomeThemePalette.m \
	Source/Rendering/GnomeThemeControls.m \
	Source/Rendering/GnomeThemeMenusAndData.m

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

.PHONY: demo installdemo adwaita-demo adwaita-metrics

demo:
	$(MAKE) -C Examples/ThemeDemo

installdemo:
	$(MAKE) -C Examples/ThemeDemo install

adwaita-demo:
	python3 Reference/AdwaitaDemo/adwaita_demo.py

adwaita-metrics:
	python3 Reference/AdwaitaDemo/adwaita_demo.py --dump-metrics
