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
#import <objc/runtime.h>

static NSString *GnomeThemeRuntimeDefaultsDomain = @"GnomeThemeRuntimeDomain";

@interface GnomeTheme ()
- (void) applyRuntimeDefaults;
- (void) removeRuntimeDefaults;
- (void) windowNeedsMainMenu: (NSNotification *)notification;
- (NSDictionary *) runtimeDefaultsDictionary;
- (void) addFont: (NSFont *)font
          forKey: (NSString *)key
     toDictionary: (NSMutableDictionary *)dictionary;
@end

IMP
GnomeThemeOriginalMethod(SEL selector, id receiver, Class baseClass)
{
  static NSMapTable *prototypes = nil;
  GSTheme *theme = [GSTheme theme];
  IMP imp = [theme overriddenMethod: selector for: receiver];
  id prototype;

  if (imp != NULL || baseClass == Nil)
    {
      return imp;
    }
  /* An instance of exactly `baseClass`, used only as a lookup key: it is never
     initialised, messaged, or freed. */
  if (prototypes == nil)
    {
      prototypes = [[NSMapTable alloc] initWithKeyOptions: NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality
                                             valueOptions: NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality
                                                 capacity: 16];
    }
  prototype = (id)NSMapGet (prototypes, (void *)baseClass);
  if (prototype == nil)
    {
      prototype = class_createInstance (baseClass, 0);
      NSMapInsert (prototypes, (void *)baseClass, (void *)prototype);
    }
  return [theme overriddenMethod: selector for: prototype];
}

const CGFloat GnomeThemeApplicationMenuIconWidth = 16.0;

/* The title GSTheme gives the application item (-organizeMenu:isHorizontal:). */
static NSString *
GnomeThemeApplicationMenuTitle(void)
{
  NSString *title = [[[NSBundle mainBundle] localizedInfoDictionary]
                      objectForKey: @"ApplicationName"];

  return (title != nil) ? title : [[NSProcessInfo processInfo] processName];
}

BOOL
GnomeThemeIsApplicationMenuItem(NSMenuItem *item)
{
  NSMenu *mainMenu = [NSApp mainMenu];

  if (item == nil || mainMenu == nil || [item menu] != mainMenu
    || [item hasSubmenu] == NO || [mainMenu indexOfItem: item] != 0)
    {
      return NO;
    }
  return [[item title] isEqualToString: GnomeThemeApplicationMenuTitle ()];
}

/* Three short lines: GNOME's open-menu-symbolic. */
static void
GnomeThemeDrawApplicationMenuIcon(NSRect rect, NSColor *color)
{
  CGFloat width = GnomeThemeApplicationMenuIconWidth - 2.0;
  CGFloat x = floor (NSMidX (rect) - width / 2.0);
  CGFloat y = floor (NSMidY (rect)) - 6.0;
  NSInteger line;

  [color set];
  for (line = 0; line < 3; line++)
    {
      NSRectFill (NSMakeRect (x, y + 5.0 * line, width, 2.0));
    }
}

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
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

  [self reloadConfiguration];
  [self applyRuntimeDefaults];
  [super activate];
  [center addObserver: self
             selector: @selector(windowNeedsMainMenu:)
                 name: NSWindowDidBecomeKeyNotification
               object: nil];
  [center addObserver: self
             selector: @selector(windowNeedsMainMenu:)
                 name: NSWindowDidBecomeMainNotification
               object: nil];
}

- (void) deactivate
{
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

  [center removeObserver: self name: NSWindowDidBecomeKeyNotification object: nil];
  [center removeObserver: self name: NSWindowDidBecomeMainNotification object: nil];
  [self removeRuntimeDefaults];
  [super deactivate];
}

/* With NSWindows95InterfaceStyle, GNUstep puts the main menu only into the
   windows that exist when the menu is first updated (-[NSMenu update] calls
   -updateAllWindowsWithMenu: once), so a window created after launch has no
   menu bar. Attach it when such a window becomes key or main. Windows given a
   menu of their own, and windows that can't become main (panels, menus), are
   left alone. */
- (void) windowNeedsMainMenu: (NSNotification *)notification
{
  NSWindow *window = [notification object];
  NSMenu *mainMenu = [NSApp mainMenu];

  if (mainMenu == nil || [window isKindOfClass: [NSWindow class]] == NO)
    {
      return;
    }
  if (NSInterfaceStyleForKey (@"NSMenuInterfaceStyle", nil) != NSWindows95InterfaceStyle)
    {
      return;
    }
  if ([window canBecomeMainWindow] == NO || [window menu] != nil)
    {
      return;
    }
  [self updateMenu: mainMenu forWindow: window];
}

- (NSColorList *) colors
{
  if (_palette == nil)
    {
      _palette = RETAIN ([GnomeThemePalette colorListForSettings: _settings]);
    }
  return _palette;
}

/* GSTheme reads these from a ThemeExtra colour list; the theme's colours are
   in its palette. */
- (NSColor *) toolbarBackgroundColor
{
  NSColor *color = [[self colors] colorWithKey: @"toolbarBackgroundColor"];

  return (color != nil) ? color : [super toolbarBackgroundColor];
}

- (NSColor *) toolbarBorderColor
{
  NSColor *color = [[self colors] colorWithKey: @"toolbarBorderColor"];

  return (color != nil) ? color : [super toolbarBorderColor];
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

  if (isHorizontal && GnomeThemeIsApplicationMenuItem ([cell menuItem]))
    {
      GnomeThemeDrawApplicationMenuIcon (cellFrame, textColor);
      return;
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

/* GNOME apps have no menu named after the app. GSTheme puts one first in a
   horizontal main menu, collecting the menu's loose items (Info, Quit, ...);
   when there were none it is empty and drawn disabled, so remove it. A
   non-empty one is drawn as the GNOME main-menu icon (see
   -drawTitleForMenuItemCell:...). GNUstep can't hide menu items, and moving
   the item to the end (where GNOME puts the main menu) doesn't last: GSTheme
   moves it back to the front. */
- (void) organizeMenu: (NSMenu *)menu
         isHorizontal: (BOOL)horizontal
{
  [super organizeMenu: menu isHorizontal: horizontal];

  if (horizontal && [menu numberOfItems] > 0)
    {
      NSMenuItem *first = (NSMenuItem *)[menu itemAtIndex: 0];

      if (GnomeThemeIsApplicationMenuItem (first) && [[first submenu] numberOfItems] == 0)
        {
          [menu removeItemAtIndex: 0];
        }
    }
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
  NSFont *boldInterfaceFont = [_settings boldInterfaceFont];
  NSFont *menuFont = [_settings menuFont];
  NSFont *menuBarFont = [_settings menuBarFont];
  NSFont *fixedPitchFont = [_settings fixedPitchFont];
  CGFloat baseFontSize = [_settings interfaceFontSize];

  [self addFont: interfaceFont forKey: @"NSFont" toDictionary: dictionary];
  [self addFont: boldInterfaceFont forKey: @"NSBoldFont" toDictionary: dictionary];
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
