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
  /* libadwaita 1.7's window_bg_color, with its slight blue. */
  [colors setColor: GnomeThemeColorFromHex (@"#fafafb") forKey: @"windowBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#ffffff") forKey: @"controlBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#ebebeb") forKey: @"controlColor"];
  /* The light edges of 3D bevels (GNUstep's grooves and bezels, as in Gorm's
     boxes), not selection colours: GNUstep's own are white. */
  [colors setColor: GnomeThemeColorFromHex (@"#ffffff") forKey: @"controlHighlightColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#ffffff") forKey: @"controlLightHighlightColor"];
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
  /* Toolbars sit on the window background, like a GNOME header bar, with a
     light bottom edge (GSTheme's fallback is dark grey). */
  [colors setColor: GnomeThemeColorFromHex (@"#fafafb") forKey: @"toolbarBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#e6e6e6") forKey: @"toolbarBorderColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#d6d6d6") forKey: @"menuBorderColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#c7c7c7") forKey: @"scrollBarColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#e8e8e8") forKey: @"headerColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#1f1f1f") forKey: @"headerTextColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#d6d6d6") forKey: @"gridColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#dfe6ef") forKey: @"highlightedTableRowBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#1f1f1f") forKey: @"highlightedTableRowTextColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#ffffff") forKey: @"rowBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#f6f6f6") forKey: @"alternateRowBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#1c71d8") forKey: @"keyboardFocusIndicatorColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#3584e4") forKey: @"highlightColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#8c8c8c") forKey: @"shadowColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#ffffff") forKey: @"windowFrameTextColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#4a4a4a") forKey: @"windowFrameColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#99c1f1") forKey: @"selectedTextBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#1f1f1f") forKey: @"selectedTextColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#1f1f1f") forKey: @"labelColor"];
  /* libadwaita's dimmed labels: the text colour at 55% over the window
     background; the next steps down at 40% and 25%. Unset, libs-gui gives
     them black (#51). */
  [colors setColor: GnomeThemeColorFromHex (@"#828282") forKey: @"secondaryLabelColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#a2a2a2") forKey: @"tertiaryLabelColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#c3c3c3") forKey: @"quaternaryLabelColor"];
  /* libadwaita's tool tips are 80% black over whatever is behind them; our
     tool tip windows are opaque, so this is that over the window
     background. */
  [colors setColor: GnomeThemeColorFromHex (@"#323232") forKey: @"toolTipColor"];
  [colors setColor: [NSColor whiteColor] forKey: @"toolTipTextColor"];
}

static void
GnomeThemePopulateDarkPalette(NSColorList *colors)
{
  [colors setColor: GnomeThemeColorFromHex (@"#222226") forKey: @"windowBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#303030") forKey: @"controlBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#3a3a3a") forKey: @"controlColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#484848") forKey: @"controlHighlightColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#555555") forKey: @"controlLightHighlightColor"];
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
  /* libadwaita's view_bg_color: text views and other content. */
  [colors setColor: GnomeThemeColorFromHex (@"#1d1d20") forKey: @"textBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#f5f5f5") forKey: @"textColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#4f7cb8") forKey: @"selectedMenuItemColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#ffffff") forKey: @"selectedMenuItemTextColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#2b2b2b") forKey: @"menuBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#2b2b2b") forKey: @"menuItemBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#4a4a4a") forKey: @"menuSeparatorColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#222226") forKey: @"menuBarBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#3d3d3d") forKey: @"menuBarBorderColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#222226") forKey: @"toolbarBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#1a1a1a") forKey: @"toolbarBorderColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#3d3d3d") forKey: @"menuBorderColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#525252") forKey: @"scrollBarColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#303030") forKey: @"headerColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#f5f5f5") forKey: @"headerTextColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#3d3d3d") forKey: @"gridColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#355278") forKey: @"highlightedTableRowBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#ffffff") forKey: @"highlightedTableRowTextColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#222226") forKey: @"rowBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#2b2b2b") forKey: @"alternateRowBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#78aeed") forKey: @"keyboardFocusIndicatorColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#78aeed") forKey: @"highlightColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#101010") forKey: @"shadowColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#ffffff") forKey: @"windowFrameTextColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#101010") forKey: @"windowFrameColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#78aeed") forKey: @"selectedTextBackgroundColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#0f1720") forKey: @"selectedTextColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#f5f5f5") forKey: @"labelColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#979797") forKey: @"secondaryLabelColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#787878") forKey: @"tertiaryLabelColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#585858") forKey: @"quaternaryLabelColor"];
  [colors setColor: GnomeThemeColorFromHex (@"#070707") forKey: @"toolTipColor"];
  [colors setColor: [NSColor whiteColor] forKey: @"toolTipTextColor"];
}

/* libadwaita's high contrast keeps the light or dark palette and makes
   its lines stronger (its base-hc.css): borders and separators are the
   text colour at 50% instead of 15%, disabled controls fade to 40%
   instead of 50%, so they stand apart from enabled ones, and dimmed
   labels are stronger. */
static void
GnomeThemeApplyHighContrast(NSColorList *colors)
{
  NSColor *text = [colors colorWithKey: @"controlTextColor"];
  NSColor *background = [colors colorWithKey: @"windowBackgroundColor"];
  NSColor *border = [background blendedColorWithFraction: 0.5 ofColor: text];
  NSColor *strongBorder = [background blendedColorWithFraction: 0.7 ofColor: text];
  NSColor *disabled = [background blendedColorWithFraction: 0.4 ofColor: text];
  NSArray *borders = [NSArray arrayWithObjects: @"controlShadowColor", @"menuBorderColor", @"menuBarBorderColor",
                              @"toolbarBorderColor", @"menuSeparatorColor", @"gridColor", nil];
  NSEnumerator *enumerator = [borders objectEnumerator];
  NSString *key;

  if (text == nil || background == nil)
    {
      return;
    }
  while ((key = [enumerator nextObject]) != nil)
    {
      [colors setColor: border forKey: key];
    }
  [colors setColor: strongBorder forKey: @"controlDarkShadowColor"];
  [colors setColor: disabled forKey: @"disabledControlTextColor"];
  /* Dimmed labels stay readable: 80%, 65% and 50% instead of 55%, 40%
     and 25%. */
  [colors setColor: [background blendedColorWithFraction: 0.8 ofColor: text] forKey: @"secondaryLabelColor"];
  [colors setColor: [background blendedColorWithFraction: 0.65 ofColor: text] forKey: @"tertiaryLabelColor"];
  [colors setColor: [background blendedColorWithFraction: 0.5 ofColor: text] forKey: @"quaternaryLabelColor"];
}

/* libadwaita 1.7 draws its controls in the foreground colour at an opacity
   over the window background (alpha(currentColor, …)): buttons, entries
   and pop-ups at 10%, troughs and unchecked check boxes' and radios' rings
   at 15% (30% in high contrast), checked toggles and pressed buttons at
   30%; disabled controls are those at half opacity (40% in high
   contrast). High contrast adds a 1px outline, the foreground at 50%.
   The foreground is libadwaita's window_fg_color as it shows over the
   window: rgba(0, 0, 6, 0.8) in the light style, white in the dark one.
   These are the theme's own keys (GnomeThemePaletteColor() in the
   renderers reads them). */
static void
GnomeThemeAddWidgetColors(NSColorList *colors, NSColor *foreground, BOOL highContrast)
{
  NSColor *window = [colors colorWithKey: @"windowBackgroundColor"];
  NSColor *button = nil;
  NSColor *trough = nil;

  if (window == nil || foreground == nil)
    {
      return;
    }
  button = [window blendedColorWithFraction: 0.10 ofColor: foreground];
  trough = [window blendedColorWithFraction: (highContrast ? 0.30 : 0.15) ofColor: foreground];
  [colors setColor: foreground forKey: @"GnomeThemeForegroundColor"];
  [colors setColor: button forKey: @"GnomeThemeButtonColor"];
  [colors setColor: [window blendedColorWithFraction: 0.30 ofColor: foreground]
            forKey: @"GnomeThemeButtonPressedColor"];
  [colors setColor: [button blendedColorWithFraction: (highContrast ? 0.6 : 0.5) ofColor: window]
            forKey: @"GnomeThemeButtonDisabledColor"];
  [colors setColor: trough forKey: @"GnomeThemeTroughColor"];
  /* Separators inside a control (a spin button's): the trough's 15%, or
     the outline in high contrast. */
  [colors setColor: (highContrast
                       ? [window blendedColorWithFraction: 0.5 ofColor: foreground]
                       : [window blendedColorWithFraction: 0.15 ofColor: foreground])
            forKey: @"GnomeThemeSeparatorColor"];
  if (highContrast)
    {
      [colors setColor: [window blendedColorWithFraction: 0.5 ofColor: foreground]
                forKey: @"GnomeThemeOutlineColor"];
    }
}

@implementation GnomeThemePalette

+ (NSColorList *) colorListForSettings: (GnomeThemeSettings *)settings
{
  NSColorList *colors = AUTORELEASE ([[NSColorList alloc] initWithName: @"System"
                                                              fromFile: nil]);
  BOOL dark = [settings prefersDarkAppearance];
  BOOL highContrast = [settings highContrastEnabled];

  if (dark)
    {
      GnomeThemePopulateDarkPalette (colors);
    }
  else
    {
      GnomeThemePopulateLightPalette (colors);
    }
  if (highContrast)
    {
      GnomeThemeApplyHighContrast (colors);
    }
  GnomeThemeAddWidgetColors (colors,
                             GnomeThemeColorFromHex (dark ? @"#ffffff" : @"#323237"),
                             highContrast);

  return colors;
}

@end
