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

#import "GnomeTheme.h"
#import "Settings/GnomeThemeSettings.h"
#import "Settings/GnomeThemeMetrics.h"
#import "Rendering/GnomeThemePalette.h"

#import <AppKit/AppKit.h>

static NSString *GnomeThemeRuntimeDefaultsDomain = @"GnomeThemeRuntimeDomain";

@interface GnomeTheme ()
- (void) applyRuntimeDefaults;
- (void) removeRuntimeDefaults;
- (NSDictionary *) runtimeDefaultsDictionary;
- (void) addFont: (NSFont *)font
          forKey: (NSString *)key
     toDictionary: (NSMutableDictionary *)dictionary;
@end

@implementation GnomeTheme

+ (NSString *)themeName
{
  return @"Adwaita";
}

- (id) initWithBundle: (NSBundle *)bundle
{
  self = [super initWithBundle: bundle];
  if (self != nil)
    {
      _settings = [GnomeThemeSettings new];
      _metrics = [GnomeThemeMetrics new];
      [self reloadConfiguration];
    }
  return self;
}

- (void) dealloc
{
  RELEASE (_settings);
  RELEASE (_metrics);
  RELEASE (_palette);
  [super dealloc];
}

- (void) reloadConfiguration
{
  [_settings reload];
  [_metrics reloadFromSettings: _settings];
  DESTROY (_palette);
}

- (GnomeThemeSettings *) settings
{
  return _settings;
}

- (GnomeThemeMetrics *) metrics
{
  return _metrics;
}

- (void) activate
{
  [self reloadConfiguration];
  [self applyRuntimeDefaults];
  [super activate];
}

- (void) deactivate
{
  [self removeRuntimeDefaults];
  [super deactivate];
}

- (NSColorList *) colors
{
  if (_palette == nil)
    {
      _palette = RETAIN ([GnomeThemePalette colorListForSettings: _settings]);
    }
  return _palette;
}

- (BOOL) menuShouldShowIcon
{
  return NO;
}

- (CGFloat) menuBarHeight
{
  return [_metrics menuBarHeight];
}

- (CGFloat) menuItemHeight
{
  return [_metrics menuItemHeight];
}

- (CGFloat) menuSeparatorHeight
{
  return [_metrics menuSeparatorHeight];
}

- (float) defaultScrollerWidth
{
  return [_metrics scrollerWidth];
}

- (GSThemeMargins) buttonMarginsForCell: (NSCell *)cell
                                  style: (int)style
                                  state: (GSThemeControlState)state
{
  GSThemeMargins margins = [super buttonMarginsForCell: cell
                                                 style: style
                                                 state: state];
  CGFloat horizontal = [_metrics buttonHorizontalPadding];
  CGFloat vertical = [_metrics buttonVerticalPadding];

  switch (style)
    {
      case NSRoundedBezelStyle:
      case NSRoundRectBezelStyle:
      case NSTexturedRoundedBezelStyle:
        margins.left = MAX (margins.left, horizontal);
        margins.right = MAX (margins.right, horizontal);
        margins.top = MAX (margins.top, vertical);
        margins.bottom = MAX (margins.bottom, vertical);
        break;

      default:
        break;
    }

  return margins;
}

- (CGFloat) tabHeightForType: (NSTabViewType)type
{
  CGFloat height = [super tabHeightForType: type];

  switch (type)
    {
      case NSTopTabsBezelBorder:
      case NSBottomTabsBezelBorder:
      case NSLeftTabsBezelBorder:
      case NSRightTabsBezelBorder:
        height = MAX (height, [_metrics minimumTabHeight]);
        break;

      default:
        break;
    }

  return height;
}

- (CGFloat) proposedTitleWidth: (CGFloat)proposedWidth
                   forMenuView: (NSMenuView *)aMenuView
{
  CGFloat padding = [_metrics horizontalMenuTitlePadding];

  if ([aMenuView isHorizontal] == YES)
    {
      return proposedWidth + (padding * 2.5);
    }
  return proposedWidth + padding;
}

- (void) drawTitleForMenuItemCell: (NSMenuItemCell *)cell
                        withFrame: (NSRect)cellFrame
                           inView: (NSView *)controlView
                            state: (GSThemeControlState)state
                     isHorizontal: (BOOL)isHorizontal
{
  NSRect titleRect = [cell titleRectForBounds: cellFrame];
  NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
  NSFont *font = nil;
  NSColor *textColor = nil;
  BOOL highlighted = [cell isHighlighted]
    || (state == GSThemeSelectedState)
    || (state == GSThemeSelectedFirstResponderState)
    || (state == GSThemeHighlightedState)
    || (state == GSThemeHighlightedFirstResponderState);
  NSDictionary *sizingAttributes = nil;
  NSSize titleSize;
  NSString *title = [[cell menuItem] title];

  if (isHorizontal)
    {
      font = [_settings menuBarFont];
    }
  else
    {
      font = [cell font];
      if (font == nil)
        {
          font = [_settings menuFont];
        }
    }

  if (font != nil)
    {
      [attributes setObject: font forKey: NSFontAttributeName];
    }

  if (![[cell menuItem] isEnabled])
    {
      textColor = [NSColor disabledControlTextColor];
    }
  else if (highlighted)
    {
      textColor = [NSColor selectedMenuItemTextColor];
    }
  else
    {
      textColor = [NSColor controlTextColor];
    }

  if (textColor != nil)
    {
      [attributes setObject: textColor forKey: NSForegroundColorAttributeName];
    }

  if ([title length] == 0)
    {
      return;
    }

  sizingAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                        font, NSFontAttributeName,
                        nil];
  titleSize = [title sizeWithAttributes: sizingAttributes];
  if (isHorizontal)
    {
      titleRect.origin.x = floor (NSMidX (titleRect) - (titleSize.width / 2.0));
      titleRect.size.width = ceil (titleSize.width);
    }
  titleRect.origin.y = floor (NSMidY (titleRect) - (titleSize.height / 2.0));
  titleRect.size.height = ceil (titleSize.height);

  [title drawInRect: titleRect withAttributes: attributes];
}

- (void) addFont: (NSFont *)font
          forKey: (NSString *)key
     toDictionary: (NSMutableDictionary *)dictionary
{
  if (font == nil || key == nil || dictionary == nil)
    {
      return;
    }

  [dictionary setObject: [font fontName] forKey: key];
  [dictionary setObject: [NSNumber numberWithFloat: [font pointSize]]
                 forKey: [NSString stringWithFormat: @"%@Size", key]];
}

- (NSDictionary *) runtimeDefaultsDictionary
{
  NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
  NSFont *interfaceFont = [_settings interfaceFont];
  NSFont *menuFont = [_settings menuFont];
  NSFont *menuBarFont = [_settings menuBarFont];
  NSFont *fixedPitchFont = [_settings fixedPitchFont];
  CGFloat baseFontSize = [_settings interfaceFontSize];

  [self addFont: interfaceFont forKey: @"NSFont" toDictionary: dictionary];
  [self addFont: interfaceFont forKey: @"NSUserFont" toDictionary: dictionary];
  [self addFont: interfaceFont forKey: @"NSControlContentFont" toDictionary: dictionary];
  [self addFont: interfaceFont forKey: @"NSLabelFont" toDictionary: dictionary];
  [self addFont: interfaceFont forKey: @"NSMessageFont" toDictionary: dictionary];
  [self addFont: interfaceFont forKey: @"NSToolTipsFont" toDictionary: dictionary];
  [self addFont: menuFont forKey: @"NSMenuFont" toDictionary: dictionary];
  [self addFont: menuBarFont forKey: @"NSMenuBarFont" toDictionary: dictionary];
  [self addFont: fixedPitchFont forKey: @"NSUserFixedPitchFont" toDictionary: dictionary];

  [dictionary setObject: [NSNumber numberWithFloat: baseFontSize]
                 forKey: @"NSFontSize"];
  [dictionary setObject: [NSNumber numberWithFloat: MAX (10.0, baseFontSize - 1.0)]
                 forKey: @"NSSmallFontSize"];
  [dictionary setObject: [NSNumber numberWithFloat: MAX (9.0, baseFontSize - 2.0)]
                 forKey: @"NSMiniFontSize"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics menuBarHeight]]
                 forKey: @"GSMenuBarHeight"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics menuItemHeight]]
                 forKey: @"GSMenuItemHeight"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics menuSeparatorHeight]]
                 forKey: @"GSMenuSeparatorHeight"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics scrollerWidth]]
                 forKey: @"GSScrollerDefaultWidth"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics minimumTabHeight]]
                 forKey: @"GSMinimumTabHeight"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics maximumTabHeight]]
                 forKey: @"GSMaximumTabHeightPrivate"];

  return dictionary;
}

- (void) applyRuntimeDefaults
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSMutableArray *searchList = [[defaults searchList] mutableCopy];
  NSUInteger index = NSNotFound;

  [defaults setVolatileDomain: [self runtimeDefaultsDictionary]
                      forName: GnomeThemeRuntimeDefaultsDomain];

  if ([searchList containsObject: GnomeThemeRuntimeDefaultsDomain] == NO)
    {
      index = [searchList indexOfObject: @"GSThemeDomain"];
      if (index == NSNotFound)
        {
          index = [searchList indexOfObject: GSConfigDomain];
        }
      if (index == NSNotFound)
        {
          index = [searchList indexOfObject: NSRegistrationDomain];
        }
      if (index == NSNotFound)
        {
          index = [searchList count];
        }

      [searchList insertObject: GnomeThemeRuntimeDefaultsDomain atIndex: index];
      [defaults setSearchList: searchList];
    }

  RELEASE (searchList);
}

- (void) removeRuntimeDefaults
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSMutableArray *searchList = [[defaults searchList] mutableCopy];

  [searchList removeObject: GnomeThemeRuntimeDefaultsDomain];
  [defaults setSearchList: searchList];
  [defaults removeVolatileDomainForName: GnomeThemeRuntimeDefaultsDomain];

  RELEASE (searchList);
}

@end
