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
# Xlib, for asking the window manager to move, resize and maximise windows
# with the header bar (Source/Adapters/GnomeThemeWindowManager.m).
X11_CFLAGS = $(shell pkg-config --cflags x11)
X11_LIBS = $(shell pkg-config --libs x11)

ADDITIONAL_OBJCFLAGS += -Wno-import $(GIO_CFLAGS) $(X11_CFLAGS)
ADDITIONAL_CFLAGS += $(GIO_CFLAGS)
ADDITIONAL_LDFLAGS += $(GIO_LIBS) $(X11_LIBS)

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
	Source/Rendering/GnomeThemeAlerts.m \
	Source/Rendering/GnomeThemePrimaryMenu.m \
	Source/Rendering/GnomeThemeHeaderBar.m \
	Source/Adapters/GnomeThemeWindowManager.m \
	Source/Rendering/GnomeThemeMenusAndData.m \
	Source/Rendering/GnomeThemeWindowTypes.m

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

.PHONY: demo installdemo probe check-quirks check-mutter check-mutter-shadow check-wms palette installpalette adwaita-demo adwaita-metrics

demo:
	$(MAKE) -C Examples/ThemeDemo

probe:
	$(MAKE) -C Examples/QuirkProbe

# Menu bar and primary menu, each with the window manager's title bar and
# with the theme's header bar; then the header bar's checks in the dark and
# high contrast palettes.
check-quirks:
	bash Tests/Scripts/run-quirk-probe.sh
	QUIRK_PROBE_ARGS="-GnomeThemeMenuStyle primary" bash Tests/Scripts/run-quirk-probe.sh --no-build
	QUIRK_PROBE_ARGS="-GSX11HandlesWindowDecorations NO" bash Tests/Scripts/run-quirk-probe.sh --no-build
	QUIRK_PROBE_ARGS="-GSX11HandlesWindowDecorations NO -GnomeThemeMenuStyle primary" bash Tests/Scripts/run-quirk-probe.sh --no-build
	QUIRK_PROBE_STYLE=dark QUIRK_PROBE_ARGS="-GSX11HandlesWindowDecorations NO -ProbeOnly header-bar" bash Tests/Scripts/run-quirk-probe.sh --no-build
	QUIRK_PROBE_STYLE=high-contrast QUIRK_PROBE_ARGS="-GSX11HandlesWindowDecorations NO -ProbeOnly header-bar" bash Tests/Scripts/run-quirk-probe.sh --no-build

# The header bar with Mutter as the window manager (GNOME Shell on a private
# Xvfb display; see the script).
check-mutter:
	bash Tests/Scripts/run-mutter-check.sh

# The same against a libs-gui and libs-back that draw GNOME's shadow
# (phase 2b in Docs/HANDOFF_HEADER_BAR.md), with checks of the shadow,
# corners, maximised and restored margins, resize band and click-through.
# Skipped when they aren't there.
MUTTER_CHECK_GUI ?= $(HOME)/git/gnustep/libs-gui-csd/Source/obj
MUTTER_CHECK_BACK ?= $(HOME)/git/gnustep/libs-back-csd/Source/libgnustep-back-032.bundle
check-mutter-shadow:
	MUTTER_CHECK_GUI="$(MUTTER_CHECK_GUI)" MUTTER_CHECK_BACK="$(MUTTER_CHECK_BACK)" \
	  bash Tests/Scripts/run-mutter-check.sh --shadow

# The same checks under KWin, Xfwm4 (each with its compositor) and Openbox
# with picom, with stock and with the shadow-drawing libraries
# (plugins-themes-Adwaita#14). Openbox doesn't list _GTK_FRAME_EXTENTS, so
# its windows get no margin.
check-wms:
	status=0; for wm in kwin xfwm4 openbox; do \
	  bash Tests/Scripts/run-mutter-check.sh --no-build --wm $$wm || status=1; \
	  MUTTER_CHECK_GUI="$(MUTTER_CHECK_GUI)" MUTTER_CHECK_BACK="$(MUTTER_CHECK_BACK)" \
	    bash Tests/Scripts/run-mutter-check.sh --no-build --shadow --wm $$wm || status=1; \
	done; exit $$status

installdemo:
	$(MAKE) -C Examples/ThemeDemo install

# The Gorm palette of controls at GNOME's sizes (see the README).
palette:
	$(MAKE) -C Palettes/Adwaita

installpalette:
	$(MAKE) -C Palettes/Adwaita install

adwaita-demo:
	python3 Reference/AdwaitaDemo/adwaita_demo.py

adwaita-metrics:
	python3 Reference/AdwaitaDemo/adwaita_demo.py --dump-metrics
