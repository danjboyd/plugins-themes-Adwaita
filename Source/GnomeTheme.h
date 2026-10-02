/*
   Copyright (C) 2025-2026 Daniel Boyd

   This file is part of the GNUstep Adwaita theme.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/>.
*/

#import <GNUstepGUI/GSTheme.h>

@class GnomeThemeSettings;
@class GnomeThemeMetrics;

/* The implementation a theme override replaced. GSTheme's -overriddenMethod:for:
   only matches the receiver's exact class, so when a subclass (for example
   GSToolbarButtonCell or NSMenuItemCell) reaches an override through `super`,
   it answers NULL and the override has nothing to fall back on. This looks the
   method up for `baseClass`, the class the override was installed on, instead. */
IMP GnomeThemeOriginalMethod(SEL selector, id receiver, Class baseClass);

/* YES for the application-name item GNUstep puts first in a horizontal
   (NSWindows95InterfaceStyle) main menu (see -organizeMenu:isHorizontal:). The
   theme draws it as a GNOME main-menu icon instead of the app's name. */
BOOL GnomeThemeIsApplicationMenuItem(NSMenuItem *item);

/* Width of that icon. */
extern const CGFloat GnomeThemeApplicationMenuIconWidth;

/* Draws that icon (GNOME's open-menu-symbolic) centred in `rect`. */
void GnomeThemeDrawApplicationMenuIcon(NSRect rect, NSColor *color);

/* YES when the app asked for GNOME's primary menu instead of a menu bar
   (the GnomeThemeMenuStyle default set to "primary"). */
BOOL GnomeThemeUsesPrimaryMenu(void);

/* YES when GNUstep draws the window decorations itself
   (GSX11HandlesWindowDecorations NO): the theme then draws libadwaita's
   header bar as the windows' title bar. */
BOOL GnomeThemeUsesHeaderBar(void);
/* Whether a toolbar is shown in its window's header bar row
   (GnomeThemeHeaderBarToolbar), not as a row of its own. */
BOOL GnomeThemeToolbarInHeaderBar(NSToolbar *toolbar);

/* YES when the app's first preferred language is written right to left
   (or NSForceRightToLeftWritingDirection is set): the header bar is
   mirrored, as GTK mirrors it. */
BOOL GnomeThemeUsesRightToLeft(void);

/* The colour of a header bar's title and icons in `window`: the text
   colour, dimmed when the window isn't focused. */
NSColor *GnomeThemeHeaderBarTextColor(NSWindow *window);

/* Shows `menu` with its window's top-right corner (rightAligned) or
   top-left corner at `corner` (screen coordinates) and tracks it as
   GNOME's menus behave: it stays open until a click picks an item or lands
   outside it, or Escape is pressed. Call it after the click that opens it
   has been released. */
void GnomeThemeTrackMenu(NSMenu *menu, NSPoint corner, BOOL rightAligned);

/* A new (retained) ☰ button for the header bar, from GnomeThemePrimaryMenu.m:
   a 34px button 6px from the view's right edge, centred vertically. */
NSView *GnomeThemeNewHeaderBarMenuButton(void);

@interface GnomeTheme : GSTheme
{
  GnomeThemeSettings *_settings;
  GnomeThemeMetrics *_metrics;
  NSColorList *_palette;
}

- (void) reloadConfiguration;
- (GnomeThemeSettings *) settings;
- (GnomeThemeMetrics *) metrics;

@end
