/* GSWindowTabbingTheme.m: GSTheme's plain tab bar, the default a theme
   overrides.

   Copyright (C) 2026 Daniel Boyd

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/>.
*/

#import "GSWindowTabbingPrivate.h"
#import <objc/runtime.h>

NSString *
GSWindowTabFittedTitle (NSString *title, NSDictionary *attributes, CGFloat width)
{
  NSString *ellipsis = [NSString stringWithFormat: @"%C", (unichar)0x2026];
  NSUInteger low = 0;
  NSUInteger high;

  if (title == nil)
    {
      return @"";
    }
  if ([title sizeWithAttributes: attributes].width <= width)
    {
      return title;
    }
  /* The longest start that fits with the ellipsis. */
  high = [title length];
  while (low < high)
    {
      NSUInteger middle = (low + high + 1) / 2;
      NSString *candidate = [[title substringToIndex: middle] stringByAppendingString: ellipsis];

      if ([candidate sizeWithAttributes: attributes].width <= width)
        {
          low = middle;
        }
      else
        {
          high = middle - 1;
        }
    }
  if (low == 0)
    {
      return ellipsis;
    }
  return [[title substringToIndex: low] stringByAppendingString: ellipsis];
}

#ifndef GS_HAS_WINDOW_TABBING

/* The defaults, added to GSTheme by GSWindowTabbingInstallThemeDefaults
   (self is the theme). */
@interface GSWindowTabbingThemeDefaults : NSObject
@end

@implementation GSWindowTabbingThemeDefaults

- (CGFloat) windowTabBarHeightForWindow: (NSWindow *)window
{
  return 28.0;
}

- (GSWindowTabBarPlacement) windowTabBarPlacementForWindow: (NSWindow *)window
{
  return GSWindowTabBarAboveContent;
}

- (CGFloat) windowTabMinimumWidthForWindow: (NSWindow *)window
{
  return 80.0;
}

- (CGFloat) windowTabMaximumWidthForWindow: (NSWindow *)window
{
  return 240.0;
}

- (CGFloat) windowTabNewTabButtonWidthForWindow: (NSWindow *)window
{
  return 28.0;
}

- (CGFloat) windowTabBarMarginForWindow: (NSWindow *)window
{
  return 0.0;
}

- (CGFloat) windowTabSpacingForWindow: (NSWindow *)window
{
  return 0.0;
}

/* 14pt, centred vertically, 6pt from the tab's right edge; shown on
   the selected tab and the one under the pointer. */
- (NSRect) windowTabCloseButtonRectForTabRect: (NSRect)tabRect
                                        state: (GSWindowTabState)state
                                       window: (NSWindow *)window
{
  CGFloat size = 14.0;

  if ((state & (GSWindowTabSelected | GSWindowTabHovered)) == 0)
    {
      return NSZeroRect;
    }
  return NSMakeRect (NSMaxX (tabRect) - 6.0 - size,
                     floor (NSMidY (tabRect) - size / 2.0), size, size);
}

- (void) drawWindowTabBarBackgroundInRect: (NSRect)rect window: (NSWindow *)window
{
  [[NSColor controlColor] set];
  NSRectFill (rect);
  [[NSColor controlShadowColor] set];
  NSRectFill (NSMakeRect (NSMinX (rect), NSMinY (rect), NSWidth (rect), 1.0));
}

- (void) drawWindowTab: (NSWindowTab *)tab
                inRect: (NSRect)rect
                 state: (GSWindowTabState)state
                window: (NSWindow *)window
{
  NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
  NSColor *textColor = [NSColor controlTextColor];
  NSString *title = [tab title];
  NSRect titleRect = NSInsetRect (rect, 26.0, 0.0);
  NSSize size;

  if (state & GSWindowTabSelected)
    {
      [[NSColor controlBackgroundColor] set];
      NSRectFill (NSMakeRect (NSMinX (rect), NSMinY (rect), NSWidth (rect), NSHeight (rect)));
      [[NSColor controlShadowColor] set];
      NSRectFill (NSMakeRect (NSMinX (rect), NSMinY (rect), 1.0, NSHeight (rect)));
      NSRectFill (NSMakeRect (NSMaxX (rect) - 1.0, NSMinY (rect), 1.0, NSHeight (rect)));
    }
  else
    {
      if (state & GSWindowTabHovered)
        {
          [[NSColor controlHighlightColor] set];
          NSRectFill (rect);
        }
      [[NSColor controlShadowColor] set];
      NSRectFill (NSMakeRect (NSMaxX (rect) - 1.0, NSMinY (rect) + 5.0, 1.0, NSHeight (rect) - 10.0));
    }
  if ((state & GSWindowTabWindowKey) == 0 && (state & GSWindowTabSelected) == 0)
    {
      textColor = [NSColor disabledControlTextColor];
    }
  if (state & GSWindowTabEdited)
    {
      title = [NSString stringWithFormat: @"%C %@", (unichar)0x2022, title];
    }
  [attributes setObject: [NSFont systemFontOfSize: 0.0] forKey: NSFontAttributeName];
  [attributes setObject: textColor forKey: NSForegroundColorAttributeName];
  title = GSWindowTabFittedTitle (title, attributes, NSWidth (titleRect));
  size = [title sizeWithAttributes: attributes];
  [title drawAtPoint: NSMakePoint (floor (NSMidX (titleRect) - size.width / 2.0),
                                   floor (NSMidY (rect) - size.height / 2.0))
      withAttributes: attributes];
}

static void
GSWindowTabDrawCross (NSRect rect, CGFloat inset, BOOL plus)
{
  NSBezierPath *path = [NSBezierPath bezierPath];
  NSRect r = NSInsetRect (rect, inset, inset);

  if (plus)
    {
      [path moveToPoint: NSMakePoint (NSMidX (r), NSMinY (r))];
      [path lineToPoint: NSMakePoint (NSMidX (r), NSMaxY (r))];
      [path moveToPoint: NSMakePoint (NSMinX (r), NSMidY (r))];
      [path lineToPoint: NSMakePoint (NSMaxX (r), NSMidY (r))];
    }
  else
    {
      [path moveToPoint: NSMakePoint (NSMinX (r), NSMinY (r))];
      [path lineToPoint: NSMakePoint (NSMaxX (r), NSMaxY (r))];
      [path moveToPoint: NSMakePoint (NSMinX (r), NSMaxY (r))];
      [path lineToPoint: NSMakePoint (NSMaxX (r), NSMinY (r))];
    }
  [path setLineWidth: 1.5];
  [path stroke];
}

- (void) drawWindowTabCloseButtonInRect: (NSRect)rect
                                  state: (GSWindowTabState)state
                                 window: (NSWindow *)window
{
  if (state & (GSWindowTabCloseHovered | GSWindowTabClosePressed))
    {
      [((state & GSWindowTabClosePressed) ? [NSColor controlShadowColor]
                                          : [NSColor controlHighlightColor]) set];
      [[NSBezierPath bezierPathWithOvalInRect: rect] fill];
    }
  [[NSColor controlTextColor] set];
  GSWindowTabDrawCross (rect, 4.0, NO);
}

- (void) drawWindowTabNewTabButtonInRect: (NSRect)rect
                                   state: (GSWindowTabState)state
                                  window: (NSWindow *)window
{
  NSRect button = NSInsetRect (rect, 4.0, 4.0);

  if (state & (GSWindowTabHovered | GSWindowTabPressed))
    {
      [((state & GSWindowTabPressed) ? [NSColor controlShadowColor]
                                     : [NSColor controlHighlightColor]) set];
      NSRectFill (button);
    }
  [[NSColor controlTextColor] set];
  GSWindowTabDrawCross (button, 6.0, YES);
}

@end

void
GSWindowTabbingInstallThemeDefaults (void)
{
  Class donor = [GSWindowTabbingThemeDefaults class];
  Class theme = [GSTheme class];
  unsigned int count = 0;
  unsigned int i;
  Method *methods = class_copyMethodList (donor, &count);

  for (i = 0; i < count; i++)
    {
      SEL selector = method_getName (methods[i]);

      if (class_getInstanceMethod (theme, selector) == NULL)
        {
          class_addMethod (theme, selector, method_getImplementation (methods[i]),
                           method_getTypeEncoding (methods[i]));
        }
    }
  free (methods);
}

#endif /* GS_HAS_WINDOW_TABBING */
