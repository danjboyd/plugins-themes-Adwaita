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

#import <AppKit/AppKit.h>

typedef enum
{
  GnomeThemeColorSchemeDefault = 0,
  GnomeThemeColorSchemePreferLight = 1,
  GnomeThemeColorSchemePreferDark = 2
} GnomeThemeColorScheme;

@interface GnomeThemeSettings : NSObject
{
  NSString *_interfaceFontName;
  CGFloat _interfaceFontSize;
  NSString *_monospaceFontName;
  CGFloat _monospaceFontSize;
  NSString *_gtkThemeName;
  GnomeThemeColorScheme _colorScheme;
  BOOL _highContrast;
  BOOL _compactMetrics;
}

- (void) reload;

- (NSString *) interfaceFontName;
- (CGFloat) interfaceFontSize;
- (NSString *) monospaceFontName;
- (CGFloat) monospaceFontSize;
- (NSString *) gtkThemeName;
- (BOOL) prefersDarkAppearance;
- (BOOL) highContrastEnabled;
/* GNUstep's metrics (12pt text, GNUstep's button margins and tab height)
   instead of GNOME's, for apps whose windows come from Gorm or nib files and
   were laid out at those metrics. The GnomeThemeMetrics default chooses
   ("compact" or "gnome"), then the same key in the app's Info.plist;
   otherwise apps with a main nib, storyboard or markup file get compact
   metrics. */
- (BOOL) compactMetrics;

- (NSFont *) interfaceFont;
- (NSFont *) boldInterfaceFont;
- (NSFont *) menuFont;
- (NSFont *) menuBarFont;
- (NSFont *) fixedPitchFont;

@end
