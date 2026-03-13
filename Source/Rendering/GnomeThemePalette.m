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

#import "GnomeThemePalette.h"
#import "../Settings/GnomeThemeSettings.h"

#import <AppKit/AppKit.h>

static NSColor *
GnomeThemeColorFromHex(NSString *hex)
{
  unsigned int value = 0;
  NSScanner *scanner = nil;

  if ([hex hasPrefix: @"#"])
    {
      hex = [hex substringFromIndex: 1];
    }

  scanner = [NSScanner scannerWithString: hex];
  if ([scanner scanHexInt: &value] == NO)
    {
      return [NSColor blackColor];
    }

  return [NSColor colorWithCalibratedRed: ((value >> 16) & 0xff) / 255.0
                                   green: ((value >> 8) & 0xff) / 255.0
                                    blue: (value & 0xff) / 255.0
                                   alpha: 1.0];
}

static void
GnomeThemePopulateLightPalette(NSColorList *colors)
{
  [colors setColor: GnomeThemeColorFromHex (@"#fafafa") forKey: @"windowBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#ffffff") forKey: @"controlBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#ebebeb") forKey: @"controlColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#3584e4") forKey: @"controlHighlightColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#99c1f1") forKey: @"controlLightHighlightColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#c7c7c7") forKey: @"controlShadowColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#8c8c8c") forKey: @"controlDarkShadowColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#1f1f1f") forKey: @"controlTextColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#7a7a7a") forKey: @"disabledControlTextColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#3584e4") forKey: @"selectedControlColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#ffffff") forKey: @"selectedControlTextColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#99c1f1") forKey: @"alternateSelectedControlColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#102d4d") forKey: @"alternateSelectedControlTextColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#e6edf7") forKey: @"secondarySelectedControlColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#eceff3") forKey: @"selectedInactiveColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#ffffff") forKey: @"textBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#1f1f1f") forKey: @"textColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#3584e4") forKey: @"selectedMenuItemColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#ffffff") forKey: @"selectedMenuItemTextColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#ffffff") forKey: @"menuBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#ffffff") forKey: @"menuItemBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#d0d0d0") forKey: @"menuSeparatorColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#f6f6f6") forKey: @"menuBarBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#d6d6d6") forKey: @"menuBarBorderColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#d6d6d6") forKey: @"menuBorderColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#c7c7c7") forKey: @"scrollBarColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#e8e8e8") forKey: @"headerColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#1f1f1f") forKey: @"headerTextColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#d6d6d6") forKey: @"gridColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#dbe7fb") forKey: @"highlightedTableRowBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#1f1f1f") forKey: @"highlightedTableRowTextColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#ffffff") forKey: @"rowBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#f6f6f6") forKey: @"alternateRowBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#1c71d8") forKey: @"keyboardFocusIndicatorColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#3584e4") forKey: @"highlightColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#8c8c8c") forKey: @"shadowColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#ffffff") forKey: @"windowFrameTextColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#4a4a4a") forKey: @"windowFrameColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#3584e4") forKey: @"selectedTextBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#ffffff") forKey: @"selectedTextColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#1f1f1f") forKey: @"labelColor"];
}

static void
GnomeThemePopulateDarkPalette(NSColorList *colors)
{
  [colors setColor: GnomeThemeColorFromHex (@"#242424") forKey: @"windowBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#303030") forKey: @"controlBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#3a3a3a") forKey: @"controlColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#78aeed") forKey: @"controlHighlightColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#8ec0ff") forKey: @"controlLightHighlightColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#1f1f1f") forKey: @"controlShadowColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#101010") forKey: @"controlDarkShadowColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#f5f5f5") forKey: @"controlTextColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#9a9a9a") forKey: @"disabledControlTextColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#78aeed") forKey: @"selectedControlColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#0f1720") forKey: @"selectedControlTextColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#4f7cb8") forKey: @"alternateSelectedControlColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#f5f5f5") forKey: @"alternateSelectedControlTextColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#3d4f66") forKey: @"secondarySelectedControlColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#36393d") forKey: @"selectedInactiveColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#1f1f1f") forKey: @"textBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#f5f5f5") forKey: @"textColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#4f7cb8") forKey: @"selectedMenuItemColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#ffffff") forKey: @"selectedMenuItemTextColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#2b2b2b") forKey: @"menuBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#2b2b2b") forKey: @"menuItemBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#4a4a4a") forKey: @"menuSeparatorColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#242424") forKey: @"menuBarBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#3d3d3d") forKey: @"menuBarBorderColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#3d3d3d") forKey: @"menuBorderColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#525252") forKey: @"scrollBarColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#303030") forKey: @"headerColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#f5f5f5") forKey: @"headerTextColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#3d3d3d") forKey: @"gridColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#355278") forKey: @"highlightedTableRowBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#ffffff") forKey: @"highlightedTableRowTextColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#242424") forKey: @"rowBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#2b2b2b") forKey: @"alternateRowBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#78aeed") forKey: @"keyboardFocusIndicatorColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#78aeed") forKey: @"highlightColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#101010") forKey: @"shadowColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#ffffff") forKey: @"windowFrameTextColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#101010") forKey: @"windowFrameColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#78aeed") forKey: @"selectedTextBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#0f1720") forKey: @"selectedTextColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#f5f5f5") forKey: @"labelColor"];
}

static void
GnomeThemePopulateHighContrastPalette(NSColorList *colors)
{
  [colors setColor: [NSColor blackColor] forKey: @"windowBackgroundColor"];
  [colors setColor: [NSColor blackColor] forKey: @"controlBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#1f1f1f") forKey: @"controlColor"];
  [colors setColor: [NSColor whiteColor] forKey: @"controlHighlightColor"];
  [colors setColor: [NSColor whiteColor] forKey: @"controlLightHighlightColor"];
  [colors setColor: [NSColor whiteColor] forKey: @"controlTextColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#c0c0c0") forKey: @"disabledControlTextColor"];
  [colors setColor: [NSColor whiteColor] forKey: @"selectedControlColor"];
  [colors setColor: [NSColor blackColor] forKey: @"selectedControlTextColor"];
  [colors setColor: [NSColor whiteColor] forKey: @"secondarySelectedControlColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#2a2a2a") forKey: @"selectedInactiveColor"];
  [colors setColor: [NSColor whiteColor] forKey: @"selectedMenuItemColor"];
  [colors setColor: [NSColor blackColor] forKey: @"selectedMenuItemTextColor"];
  [colors setColor: [NSColor blackColor] forKey: @"menuBackgroundColor"];
  [colors setColor: [NSColor blackColor] forKey: @"menuItemBackgroundColor"];
  [colors setColor: [NSColor whiteColor] forKey: @"menuSeparatorColor"];
  [colors setColor: [NSColor blackColor] forKey: @"menuBarBackgroundColor"];
  [colors setColor: [NSColor whiteColor] forKey: @"menuBarBorderColor"];
  [colors setColor: [NSColor whiteColor] forKey: @"menuBorderColor"];
  [colors setColor: [NSColor whiteColor] forKey: @"scrollBarColor"];
  [colors setColor: [NSColor blackColor] forKey: @"textBackgroundColor"];
  [colors setColor: [NSColor whiteColor] forKey: @"textColor"];
  [colors setColor: [NSColor whiteColor] forKey: @"keyboardFocusIndicatorColor"];
  [colors setColor: [NSColor whiteColor] forKey: @"highlightColor"];
  [colors setColor: [NSColor whiteColor] forKey: @"windowFrameTextColor"];
  [colors setColor: [NSColor blackColor] forKey: @"windowFrameColor"];
  [colors setColor: [NSColor whiteColor] forKey: @"gridColor"];
  [colors setColor: [NSColor whiteColor] forKey: @"highlightedTableRowBackgroundColor"];
  [colors setColor: [NSColor blackColor] forKey: @"highlightedTableRowTextColor"];
  [colors setColor: [NSColor blackColor] forKey: @"rowBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#1f1f1f") forKey: @"alternateRowBackgroundColor"];
  [colors setColor: [NSColor whiteColor] forKey: @"headerColor"];
  [colors setColor: [NSColor blackColor] forKey: @"headerTextColor"];
  [colors setColor: [NSColor whiteColor] forKey: @"labelColor"];
}

@implementation GnomeThemePalette

+ (NSColorList *) colorListForSettings: (GnomeThemeSettings *)settings
{
  NSColorList *colors = AUTORELEASE ([[NSColorList alloc] initWithName: @"System"
                                                              fromFile: nil]);

  if ([settings highContrastEnabled])
    {
      GnomeThemePopulateHighContrastPalette (colors);
    }
  else if ([settings prefersDarkAppearance])
    {
      GnomeThemePopulateDarkPalette (colors);
    }
  else
    {
      GnomeThemePopulateLightPalette (colors);
    }

  return colors;
}

@end
