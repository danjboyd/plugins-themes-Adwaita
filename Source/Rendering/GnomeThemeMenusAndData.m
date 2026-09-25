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

#import "../GnomeTheme.h"
#import "../Settings/GnomeThemeSettings.h"

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSTheme.h>
#import <objc/runtime.h>
#import <math.h>

/* Associated-object key: the grid lines (an NSTableViewGridLineStyle in an
   NSNumber) a table's app asked for, recorded by the -setGridStyleMask: and
   -setDrawsGrid: overrides below. */
static char GnomeThemeTableGridMaskKey;

static inline GnomeTheme *
GnomeThemeActivePhase67Theme(void)
{
  GSTheme *theme = [GSTheme theme];

  if ([theme isKindOfClass: [GnomeTheme class]] == NO)
    {
      return nil;
    }

  return (GnomeTheme *)theme;
}

static inline BOOL
GnomeThemePhase67StateIsDisabled(GSThemeControlState state)
{
  return (state == GSThemeDisabledState);
}

static inline BOOL
GnomeThemePhase67StateIsHighlighted(GSThemeControlState state)
{
  return (state == GSThemeHighlightedState
    || state == GSThemeHighlightedFirstResponderState);
}

static inline BOOL
GnomeThemePhase67StateIsSelected(GSThemeControlState state)
{
  return (state == GSThemeSelectedState
    || state == GSThemeSelectedFirstResponderState);
}

static NSColor *
GnomeThemePhase67Color(GnomeTheme *theme, NSString *key, NSColor *fallback)
{
  NSColor *color = nil;

  if (theme != nil)
    {
      color = [theme colorNamed: key state: GSThemeNormalState];
    }

  return (color != nil) ? color : fallback;
}

static NSColor *
GnomeThemePhase67Blend(NSColor *fromColor, NSColor *toColor, CGFloat fraction)
{
  NSColor *result = nil;

  if (fromColor == nil)
    {
      return toColor;
    }
  if (toColor == nil)
    {
      return fromColor;
    }

  result = [fromColor blendedColorWithFraction: fraction ofColor: toColor];
  return (result != nil) ? result : fromColor;
}

static NSBezierPath *
GnomeThemePhase67RoundedPath(NSRect rect, CGFloat radius)
{
  CGFloat clampedRadius = MIN (radius, MIN (rect.size.width, rect.size.height) / 2.0);

  if (clampedRadius <= 0.0)
    {
      return [NSBezierPath bezierPathWithRect: rect];
    }

  return [NSBezierPath bezierPathWithRoundedRect: rect
                                         xRadius: clampedRadius
                                         yRadius: clampedRadius];
}

static void
GnomeThemePhase67FillAndStrokeRoundedRect(NSRect rect,
                                          CGFloat radius,
                                          NSColor *fillColor,
                                          NSColor *strokeColor,
                                          CGFloat strokeWidth)
{
  NSBezierPath *path = GnomeThemePhase67RoundedPath (rect, radius);

  if (fillColor != nil)
    {
      [fillColor set];
      [path fill];
    }

  if (strokeColor != nil && strokeWidth > 0.0)
    {
      [strokeColor set];
      [path setLineWidth: strokeWidth];
      [path stroke];
    }
}

static BOOL
GnomeThemePhase67ViewIsActive(NSView *view)
{
  NSWindow *window = [view window];

  if (window == nil)
    {
      return YES;
    }

  return ([window isKeyWindow] || [window isMainWindow]);
}

static inline BOOL
GnomeThemePhase67UsesPopupButtonCellLayout(NSMenuItemCell *cell)
{
  return [cell isKindOfClass: [NSPopUpButtonCell class]];
}

static void
GnomeThemePhase67DrawChevron(NSRect rect,
                             BOOL horizontal,
                             BOOL increment,
                             NSColor *color)
{
  NSBezierPath *path = [NSBezierPath bezierPath];
  NSPoint center = NSMakePoint (NSMidX (rect), NSMidY (rect));
  CGFloat size = MIN (rect.size.width, rect.size.height) * 0.22;

  if (size < 3.0)
    {
      size = 3.0;
    }

  if (horizontal)
    {
      CGFloat direction = increment ? 1.0 : -1.0;

      [path moveToPoint: NSMakePoint (center.x - (direction * size * 0.6), center.y - size)];
      [path lineToPoint: NSMakePoint (center.x + (direction * size * 0.6), center.y)];
      [path lineToPoint: NSMakePoint (center.x - (direction * size * 0.6), center.y + size)];
    }
  else
    {
      CGFloat direction = increment ? 1.0 : -1.0;

      [path moveToPoint: NSMakePoint (center.x - size, center.y - (direction * size * 0.6))];
      [path lineToPoint: NSMakePoint (center.x, center.y + (direction * size * 0.6))];
      [path lineToPoint: NSMakePoint (center.x + size, center.y - (direction * size * 0.6))];
    }

  [path setLineCapStyle: NSRoundLineCapStyle];
  [path setLineJoinStyle: NSRoundLineJoinStyle];
  [path setLineWidth: 1.75];
  [color set];
  [path stroke];
}

static void
GnomeThemePhase67DrawMenuCheckmark(NSRect rect, NSColor *color)
{
  NSBezierPath *path = [NSBezierPath bezierPath];

  [path moveToPoint: NSMakePoint (rect.origin.x + rect.size.width * 0.18,
                                  rect.origin.y + rect.size.height * 0.52)];
  [path lineToPoint: NSMakePoint (rect.origin.x + rect.size.width * 0.42,
                                  rect.origin.y + rect.size.height * 0.26)];
  [path lineToPoint: NSMakePoint (rect.origin.x + rect.size.width * 0.8,
                                  rect.origin.y + rect.size.height * 0.72)];
  [path setLineWidth: 2.2];
  [path setLineCapStyle: NSRoundLineCapStyle];
  [path setLineJoinStyle: NSRoundLineJoinStyle];
  [color set];
  [path stroke];
}

static void
GnomeThemePhase67DrawMenuMixedMark(NSRect rect, NSColor *color)
{
  NSBezierPath *path = [NSBezierPath bezierPath];
  CGFloat y = NSMidY (rect);

  [path moveToPoint: NSMakePoint (rect.origin.x + rect.size.width * 0.2, y)];
  [path lineToPoint: NSMakePoint (rect.origin.x + rect.size.width * 0.8, y)];
  [path setLineWidth: 2.4];
  [path setLineCapStyle: NSRoundLineCapStyle];
  [color set];
  [path stroke];
}

static void
GnomeThemePhase67AddShortcutPart(NSMutableArray *parts, NSString *part)
{
  if ([part length] == 0)
    {
      return;
    }

  if ([parts containsObject: part] == NO)
    {
      [parts addObject: part];
    }
}

static NSString *
GnomeThemePhase67DisplayKeyForEquivalent(NSString *equivalent)
{
  if ([equivalent length] == 0)
    {
      return @"";
    }

  if ([equivalent isEqualToString: @"\r"] || [equivalent isEqualToString: @"\n"])
    {
      return @"Enter";
    }
  if ([equivalent isEqualToString: @"\t"])
    {
      return @"Tab";
    }
  if ([equivalent isEqualToString: @" "])
    {
      return @"Space";
    }
  if ([equivalent isEqualToString: @"\e"])
    {
      return @"Esc";
    }

  return [equivalent uppercaseString];
}

static NSString *
GnomeThemePhase67KeyEquivalentString(NSMenuItemCell *cell)
{
  NSMenuItem *item = [cell menuItem];

  if (item == nil)
    {
      return @"";
    }

  {
    NSMutableArray *parts = [NSMutableArray array];
    NSUInteger mask = [item keyEquivalentModifierMask];
    NSString *displayKey = GnomeThemePhase67DisplayKeyForEquivalent ([item keyEquivalent]);

    if (GnomeThemePhase67UsesPopupButtonCellLayout (cell) || [displayKey length] == 0)
      {
        return @"";
      }

    if (mask & NSCommandKeyMask)
      {
        GnomeThemePhase67AddShortcutPart (parts, @"Ctrl");
      }
    if (mask & NSControlKeyMask)
      {
        GnomeThemePhase67AddShortcutPart (parts, @"Ctrl");
      }
    if (mask & NSAlternateKeyMask)
      {
        GnomeThemePhase67AddShortcutPart (parts, @"Alt");
      }
    if (mask & NSShiftKeyMask)
      {
        GnomeThemePhase67AddShortcutPart (parts, @"Shift");
      }
    if ([displayKey length] > 0)
      {
        [parts addObject: displayKey];
      }

    return [parts componentsJoinedByString: @"+"];
  }
}

static CGFloat
GnomeThemePhase67MenuStateImageWidth(NSMenuItemCell *cell)
{
  if (GnomeThemePhase67UsesPopupButtonCellLayout (cell)
    || [[cell menuView] isHorizontal]
    || [[cell menuItem] isSeparatorItem])
    {
      return 0.0;
    }

  return 16.0;
}

static NSFont *
GnomeThemePhase67MenuShortcutFont(GnomeTheme *theme)
{
  NSFont *font = nil;
  CGFloat size = 11.0;

  if (theme != nil)
    {
      font = [[theme settings] menuFont];
    }
  if (font != nil)
    {
      size = MAX (10.0, [font pointSize] - 1.0);
      return [NSFont systemFontOfSize: size];
    }

  return [NSFont systemFontOfSize: size];
}

static CGFloat
GnomeThemePhase67MenuKeyEquivalentWidth(NSMenuItemCell *cell, GnomeTheme *theme)
{
  NSString *keyEquivalent = nil;
  NSDictionary *attributes = nil;
  NSSize keySize;

  if (GnomeThemePhase67UsesPopupButtonCellLayout (cell)
    || [[cell menuView] isHorizontal]
    || [[cell menuItem] isSeparatorItem])
    {
      return 0.0;
    }

  if ([[cell menuItem] hasSubmenu])
    {
      return 20.0;
    }

  keyEquivalent = GnomeThemePhase67KeyEquivalentString (cell);
  if ([keyEquivalent length] == 0)
    {
      return 0.0;
    }

  attributes = [NSDictionary dictionaryWithObject: GnomeThemePhase67MenuShortcutFont (theme)
                                           forKey: NSFontAttributeName];
  keySize = [keyEquivalent sizeWithAttributes: attributes];

  return ceil (keySize.width) + 12.0;
}

/* libadwaita column headers: small bold text (about 9pt against an 11pt
   interface font). */
static NSFont *
GnomeThemePhase67HeaderFont(GnomeTheme *theme)
{
  NSFont *font = nil;
  CGFloat size = 9.0;

  if (theme != nil)
    {
      font = [[theme settings] interfaceFont];
    }
  if (font != nil)
    {
      size = MAX (9.0, [font pointSize] - 3.0);
    }

  return [NSFont boldSystemFontOfSize: size];
}

static BOOL
GnomeThemePhase67MenuItemUsesDefaultStateImage(NSMenuItem *item, NSInteger state)
{
  static NSImage *defaultOnImage = nil;
  static NSImage *defaultMixedImage = nil;
  static BOOL initialized = NO;

  if (initialized == NO)
    {
      NSMenuItem *templateItem = AUTORELEASE ([[NSMenuItem alloc] initWithTitle: @"_"
                                                                         action: NULL
                                                                  keyEquivalent: @""]);
      defaultOnImage = RETAIN ([templateItem onStateImage]);
      defaultMixedImage = RETAIN ([templateItem mixedStateImage]);
      initialized = YES;
    }

  if (item == nil)
    {
      return NO;
    }

  if (state == NSOnState)
    {
      return ([item onStateImage] == defaultOnImage);
    }
  if (state == NSMixedState)
    {
      return ([item mixedStateImage] == defaultMixedImage);
    }

  return NO;
}

static NSColor *
GnomeThemePhase67MenuForegroundColor(GnomeTheme *theme,
                                     NSMenuItemCell *cell,
                                     BOOL highlighted)
{
  NSMenuItem *item = [cell menuItem];
  NSColor *color = nil;

  if ([item isEnabled] == NO)
    {
      color = GnomeThemePhase67Color (theme,
                                      @"disabledControlTextColor",
                                      [NSColor disabledControlTextColor]);
    }
  else if (highlighted)
    {
      color = GnomeThemePhase67Color (theme,
                                      @"selectedMenuItemTextColor",
                                      [NSColor selectedMenuItemTextColor]);
    }
  else
    {
      color = GnomeThemePhase67Color (theme,
                                      @"controlTextColor",
                                      [NSColor controlTextColor]);
    }

  return color;
}

/* The background rows draw on, for the table a header (or corner) view
   belongs to. */
static NSColor *
GnomeThemePhase67TableBackgroundColor(GnomeTheme *theme, NSTableView *tableView)
{
  NSColor *fallback = [tableView backgroundColor];

  if (fallback == nil)
    {
      fallback = [NSColor controlBackgroundColor];
    }
  return GnomeThemePhase67Color (theme, @"rowBackgroundColor", fallback);
}

/* libadwaita column headers sit on the list's own background, with no fill,
   border or column separators. */
static void
GnomeThemePhase67DrawHeaderBackground(GnomeTheme *theme, NSRect rect, NSTableView *tableView)
{
  [GnomeThemePhase67TableBackgroundColor (theme, tableView) set];
  NSRectFill (rect);
}

/* The grid lines to draw: the ones the app asked for, or none (the GNOME and
   Cocoa default). GNUstep draws a grid on every table by default instead
   (drawsGrid YES; on newer libs-gui, a mask with both lines), and releases
   up to at least gui 0.32.0 don't implement -gridStyleMask (it returns 0), so
   the table's own settings can't tell a default from a choice. */
static NSTableViewGridLineStyle
GnomeThemePhase67EffectiveGridMask(NSTableView *tableView)
{
  NSNumber *mask = objc_getAssociatedObject (tableView, &GnomeThemeTableGridMaskKey);

  return (mask != nil) ? (NSTableViewGridLineStyle)[mask unsignedIntegerValue] : NSTableViewGridNone;
}

static void
GnomeThemePhase67RecordTableGrid(id tableView, NSTableViewGridLineStyle mask)
{
  objc_setAssociatedObject (tableView,
                            &GnomeThemeTableGridMaskKey,
                            [NSNumber numberWithUnsignedInteger: mask],
                            OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@implementation GnomeTheme (MenusAndData)

- (CGFloat) menuSeparatorInset
{
  return 14.0;
}

- (void) drawBackgroundForMenuView: (NSMenuView *)menuView
                         withFrame: (NSRect)bounds
                         dirtyRect: (NSRect)dirtyRect
                        horizontal: (BOOL)horizontal
{
  NSColor *fillColor = nil;
  NSColor *borderColor = nil;

  (void)menuView;
  (void)dirtyRect;

  if (horizontal)
    {
      fillColor = GnomeThemePhase67Color (self,
                                          @"menuBarBackgroundColor",
                                          [NSColor windowBackgroundColor]);
      borderColor = GnomeThemePhase67Color (self,
                                            @"menuBarBorderColor",
                                            [NSColor controlShadowColor]);

      [fillColor set];
      NSRectFillUsingOperation (bounds, NSCompositeSourceOver);

      [borderColor set];
      [NSBezierPath strokeLineFromPoint: NSMakePoint (NSMinX (bounds), NSMinY (bounds) + 0.5)
                                toPoint: NSMakePoint (NSMaxX (bounds), NSMinY (bounds) + 0.5)];
    }
  else
    {
      fillColor = GnomeThemePhase67Color (self,
                                          @"menuBackgroundColor",
                                          [NSColor controlBackgroundColor]);
      borderColor = GnomeThemePhase67Color (self,
                                            @"menuBorderColor",
                                            [NSColor controlShadowColor]);

      GnomeThemePhase67FillAndStrokeRoundedRect (NSInsetRect (bounds, 0.5, 0.5),
                                                 10.0,
                                                 fillColor,
                                                 borderColor,
                                                 1.0);
    }
}

- (void) drawBorderAndBackgroundForMenuItemCell: (NSMenuItemCell *)cell
                                      withFrame: (NSRect)cellFrame
                                         inView: (NSView *)controlView
                                          state: (GSThemeControlState)state
                                   isHorizontal: (BOOL)isHorizontal
{
  NSMenuItem *item = [cell menuItem];
  BOOL disabled = GnomeThemePhase67StateIsDisabled (state) || ([item isEnabled] == NO);
  BOOL selected = GnomeThemePhase67StateIsSelected (state)
    || GnomeThemePhase67StateIsHighlighted (state)
    || [cell isHighlighted];

  if (disabled || selected == NO || [item isSeparatorItem])
    {
      return;
    }

  if (isHorizontal)
    {
      NSColor *fillColor = GnomeThemePhase67ViewIsActive (controlView)
        ? GnomeThemePhase67Color (self,
                                  @"secondarySelectedControlColor",
                                  [NSColor selectedControlColor])
        : GnomeThemePhase67Color (self,
                                  @"selectedInactiveColor",
                                  [NSColor selectedControlColor]);
      NSColor *strokeColor = GnomeThemePhase67Blend (fillColor,
                                                     GnomeThemePhase67Color (self,
                                                                             @"menuBarBorderColor",
                                                                             [NSColor controlShadowColor]),
                                                     0.28);
      NSRect pillRect = NSInsetRect (cellFrame, 6.0, 4.0);

      GnomeThemePhase67FillAndStrokeRoundedRect (NSInsetRect (pillRect, 0.5, 0.5),
                                                 8.0,
                                                 fillColor,
                                                 strokeColor,
                                                 1.0);
    }
  else
    {
      NSColor *fillColor = GnomeThemePhase67ViewIsActive (controlView)
        ? GnomeThemePhase67Color (self,
                                  @"selectedMenuItemColor",
                                  [NSColor selectedMenuItemColor])
        : GnomeThemePhase67Color (self,
                                  @"selectedInactiveColor",
                                  [NSColor selectedControlColor]);
      NSRect selectionRect = NSInsetRect (cellFrame, 4.0, 2.0);

      GnomeThemePhase67FillAndStrokeRoundedRect (NSInsetRect (selectionRect, 0.5, 0.5),
                                                 7.0,
                                                 fillColor,
                                                 nil,
                                                 0.0);
    }
}

- (void) drawSeparatorItemForMenuItemCell: (NSMenuItemCell *)cell
                                withFrame: (NSRect)cellFrame
                                   inView: (NSView *)controlView
                             isHorizontal: (BOOL)isHorizontal
{
  NSColor *separatorColor = [self menuSeparatorColor];
  CGFloat inset = [self menuSeparatorInset];
  NSBezierPath *path = [NSBezierPath bezierPath];

  (void)cell;
  (void)controlView;

  if (separatorColor == nil)
    {
      separatorColor = GnomeThemePhase67Color (self,
                                               @"menuSeparatorColor",
                                               [NSColor controlShadowColor]);
    }

  if (isHorizontal)
    {
      CGFloat x = NSMidX (cellFrame) + 0.5;

      [path moveToPoint: NSMakePoint (x, NSMinY (cellFrame) + 5.0)];
      [path lineToPoint: NSMakePoint (x, NSMaxY (cellFrame) - 5.0)];
    }
  else
    {
      CGFloat y = NSMidY (cellFrame) + 0.5;

      [path moveToPoint: NSMakePoint (NSMinX (cellFrame) + inset, y)];
      [path lineToPoint: NSMakePoint (NSMaxX (cellFrame) - inset, y)];
    }

  [path setLineWidth: 1.0];
  [separatorColor set];
  [path stroke];
}

- (NSRect) drawMenuTitleBackground: (GSTitleView *)aTitleView
                        withBounds: (NSRect)bounds
                          withClip: (NSRect)clipRect
{
  NSColor *fillColor = GnomeThemePhase67Blend (GnomeThemePhase67Color (self,
                                                                       @"menuBarBackgroundColor",
                                                                       [NSColor windowBackgroundColor]),
                                               GnomeThemePhase67Color (self,
                                                                       @"menuBackgroundColor",
                                                                       [NSColor controlBackgroundColor]),
                                               0.35);
  NSColor *borderColor = GnomeThemePhase67Color (self,
                                                 @"menuBarBorderColor",
                                                 [NSColor controlShadowColor]);

  (void)aTitleView;
  (void)clipRect;

  GnomeThemePhase67FillAndStrokeRoundedRect (NSInsetRect (bounds, 0.5, 0.5),
                                             9.0,
                                             fillColor,
                                             borderColor,
                                             1.0);
  [borderColor set];
  [NSBezierPath strokeLineFromPoint: NSMakePoint (NSMinX (bounds) + 9.0, NSMinY (bounds) + 0.5)
                            toPoint: NSMakePoint (NSMaxX (bounds) - 9.0, NSMinY (bounds) + 0.5)];

  return NSInsetRect (bounds, 12.0, 6.0);
}

/* Dim header text (libadwaita: 45% of the text colour); a clicked or
   sorted column's header gets the full text colour. */
- (NSColor *) tableHeaderTextColorForState: (GSThemeControlState)state
{
  NSColor *textColor = GnomeThemePhase67Color (self,
                                               @"headerTextColor",
                                               [NSColor headerTextColor]);
  NSColor *background = GnomeThemePhase67Color (self,
                                                @"rowBackgroundColor",
                                                [NSColor controlBackgroundColor]);

  if (GnomeThemePhase67StateIsDisabled (state))
    {
      return GnomeThemePhase67Color (self,
                                     @"disabledControlTextColor",
                                     [NSColor disabledControlTextColor]);
    }

  if (GnomeThemePhase67StateIsHighlighted (state) || GnomeThemePhase67StateIsSelected (state))
    {
      return textColor;
    }

  return GnomeThemePhase67Blend (textColor, background, 0.55);
}

- (NSRect) tableHeaderCellDrawingRectForBounds: (NSRect)theRect
{
  NSRect drawRect = NSInsetRect (theRect, 10.0, 0.0);

  drawRect.origin.y += 3.0;
  drawRect.size.height = MAX (0.0, drawRect.size.height - 6.0);
  drawRect.size.width = MAX (0.0, drawRect.size.width - 4.0);

  return drawRect;
}

- (void) drawTableHeaderCell: (NSTableHeaderCell *)cell
                   withFrame: (NSRect)cellFrame
                      inView: (NSView *)controlView
                       state: (GSThemeControlState)state
{
  NSTableView *tableView = nil;

  if ([controlView isKindOfClass: [NSTableHeaderView class]])
    {
      tableView = [(NSTableHeaderView *)controlView tableView];
    }
  GnomeThemePhase67DrawHeaderBackground (self, cellFrame, tableView);
  [cell setFont: GnomeThemePhase67HeaderFont (self)];
  [cell setTextColor: [self tableHeaderTextColorForState: state]];
  /* GNUstep centres header titles by default; GNOME (and Cocoa) start them
     at the leading edge. Titles an app aligned left or right keep that. */
  if ([cell alignment] == NSCenterTextAlignment)
    {
      [cell setAlignment: NSLeftTextAlignment];
    }
}

- (void) drawTableCornerView: (NSView *)cornerView
                    withClip: (NSRect)aRect
{
  NSTableView *tableView = nil;
  NSView *scrollView = [[cornerView superview] superview];

  (void)aRect;
  if ([scrollView isKindOfClass: [NSScrollView class]]
    && [[(NSScrollView *)scrollView documentView] isKindOfClass: [NSTableView class]])
    {
      tableView = [(NSScrollView *)scrollView documentView];
    }
  GnomeThemePhase67DrawHeaderBackground (self, [cornerView bounds], tableView);
}

- (void) drawTableViewBackgroundInClipRect: (NSRect)clipRect
                                    inView: (NSView *)view
                       withBackgroundColor: (NSColor *)backgroundColor
{
  NSTableView *tableView = (NSTableView *)view;
  NSColor *rowColor = GnomeThemePhase67Color (self,
                                              @"rowBackgroundColor",
                                              backgroundColor);
  NSColor *alternateColor = GnomeThemePhase67Color (self,
                                                    @"alternateRowBackgroundColor",
                                                    GnomeThemePhase67Blend (rowColor,
                                                                            [NSColor controlShadowColor],
                                                                            0.035));
  NSInteger rowCount = [tableView numberOfRows];
  NSInteger row = 0;

  if (rowColor == nil)
    {
      rowColor = [NSColor controlBackgroundColor];
    }

  [rowColor set];
  NSRectFillUsingOperation (clipRect, NSCompositeSourceOver);

  if ([tableView usesAlternatingRowBackgroundColors] == NO)
    {
      return;
    }

  for (row = 0; row < rowCount; row++)
    {
      NSRect rowRect = [tableView rectOfRow: row];

      if (NSMaxY (rowRect) < NSMinY (clipRect))
        {
          continue;
        }
      if (NSMinY (rowRect) > NSMaxY (clipRect))
        {
          break;
        }
      if ((row % 2) == 1)
        {
          NSRect visibleRowRect = NSIntersectionRect (rowRect, clipRect);

          [alternateColor set];
          NSRectFillUsingOperation (visibleRowRect, NSCompositeSourceOver);
        }
    }
}

- (void) drawTableViewGridInClipRect: (NSRect)aRect
                              inView: (NSView *)view
{
  NSTableView *tableView = (NSTableView *)view;
  NSColor *gridColor = GnomeThemePhase67Color (self,
                                               @"gridColor",
                                               [NSColor gridColor]);
  NSBezierPath *path = [NSBezierPath bezierPath];
  NSInteger rowCount = [tableView numberOfRows];
  NSInteger columnCount = [tableView numberOfColumns];
  NSTableViewGridLineStyle mask = GnomeThemePhase67EffectiveGridMask (tableView);
  NSInteger row = 0;
  NSInteger column = 0;

  if (mask == NSTableViewGridNone)
    {
      return;
    }
  gridColor = [gridColor colorWithAlphaComponent: 0.72];
  [gridColor set];

  for (row = 0; (mask & NSTableViewSolidHorizontalGridLineMask) != 0 && row < rowCount; row++)
    {
      NSRect rowRect = [tableView rectOfRow: row];
      CGFloat y = NSMaxY (rowRect) - 0.5;

      if (NSMaxY (rowRect) < NSMinY (aRect))
        {
          continue;
        }
      if (NSMinY (rowRect) > NSMaxY (aRect))
        {
          break;
        }

      [path moveToPoint: NSMakePoint (NSMinX (aRect), y)];
      [path lineToPoint: NSMakePoint (NSMaxX ([view bounds]), y)];
    }

  if ((mask & NSTableViewSolidVerticalGridLineMask) != 0)
    {
      for (column = 0; column < columnCount; column++)
        {
          NSRect columnRect = [tableView rectOfColumn: column];
          CGFloat x = NSMaxX (columnRect) - 0.5;

          if (NSMaxX (columnRect) < NSMinX (aRect))
            {
              continue;
            }
          if (NSMinX (columnRect) > NSMaxX (aRect))
            {
              break;
            }

          [path moveToPoint: NSMakePoint (x, NSMinY (aRect))];
          [path lineToPoint: NSMakePoint (x, NSMaxY (aRect))];
        }
    }

  [path setLineWidth: 1.0];
  [path stroke];
}

- (void) highlightTableViewSelectionInClipRect: (NSRect)clipRect
                                        inView: (NSView *)view
                              selectingColumns: (BOOL)selectingColumns
{
  NSTableView *tableView = (NSTableView *)view;
  NSColor *selectionColor = nil;
  NSIndexSet *selectionIndexes = selectingColumns
    ? [tableView selectedColumnIndexes]
    : [tableView selectedRowIndexes];
  NSUInteger index = [selectionIndexes firstIndex];

  if (index == NSNotFound)
    {
      return;
    }

  if (GnomeThemePhase67ViewIsActive (view) && [[view window] firstResponder] != nil)
    {
      NSColor *fallbackSelectionColor = GnomeThemePhase67Color (self,
                                                                @"secondarySelectedControlColor",
                                                                [NSColor alternateSelectedControlColor]);

      selectionColor = GnomeThemePhase67Color (self,
                                               @"highlightedTableRowBackgroundColor",
                                               fallbackSelectionColor);
    }
  else
    {
      selectionColor = GnomeThemePhase67Color (self,
                                               @"selectedInactiveColor",
                                               [NSColor secondarySelectedControlColor]);
      if (selectionColor == nil)
        {
          selectionColor = GnomeThemePhase67Color (self,
                                                   @"secondarySelectedControlColor",
                                                   [NSColor secondarySelectedControlColor]);
        }
    }

  while (index != NSNotFound)
    {
      NSRect itemRect = selectingColumns
        ? [tableView rectOfColumn: (NSInteger)index]
        : [tableView rectOfRow: (NSInteger)index];
      NSRect selectionRect = NSIntersectionRect (itemRect, clipRect);

      if (NSIsEmptyRect (selectionRect) == NO)
        {
          if (selectingColumns)
            {
              selectionRect.origin.y = NSMinY (clipRect);
              selectionRect.size.height = NSHeight (clipRect);
            }

          [selectionColor set];
          NSRectFillUsingOperation (selectionRect, NSCompositeSourceOver);
        }

      index = [selectionIndexes indexGreaterThanIndex: index];
    }
}

- (NSRect) drawOutlineCell: (NSTableColumn *)tb
               outlineView: (NSOutlineView *)outlineView
                      item: (id)item
               drawingRect: (NSRect)inputRect
                  rowIndex: (NSInteger)rowIndex
{
  CGFloat indentation = MAX (0.0, [outlineView indentationPerLevel] * [outlineView levelForItem: item]);
  CGFloat slotWidth = 14.0;
  CGFloat slotPadding = 6.0;
  NSRect slotRect = NSMakeRect (inputRect.origin.x + indentation + 2.0,
                                floor (NSMidY (inputRect) - 7.0),
                                slotWidth,
                                14.0);
  BOOL expandable = [outlineView isExpandable: item];

  if (tb != [outlineView outlineTableColumn])
    {
      return inputRect;
    }

  if ([outlineView respondsToSelector: @selector(frameOfOutlineCellAtRow:)])
    {
      NSRect frame = [outlineView frameOfOutlineCellAtRow: rowIndex];

      if (NSIsEmptyRect (frame) == NO)
        {
          slotRect = NSInsetRect (frame, 1.0, 1.0);
          slotRect.size.width = MIN (slotRect.size.width, slotWidth);
          slotRect.size.height = MIN (slotRect.size.height, 14.0);
          slotRect.origin.y = floor (NSMidY (inputRect) - (slotRect.size.height / 2.0));
        }
    }

  if (expandable)
    {
      NSIndexSet *selectedRows = [outlineView selectedRowIndexes];
      BOOL selected = [selectedRows containsIndex: rowIndex];
      NSColor *arrowColor = selected
        ? GnomeThemePhase67Color (self,
                                  @"highlightedTableRowTextColor",
                                  [NSColor selectedControlTextColor])
        : GnomeThemePhase67Color (self,
                                  @"controlTextColor",
                                  [NSColor controlTextColor]);

      GnomeThemePhase67DrawChevron (slotRect,
                                    [outlineView isItemExpanded: item] ? NO : YES,
                                    YES,
                                    arrowColor);
    }

  {
    CGFloat leadingInset = MAX (NSMaxX (slotRect) - inputRect.origin.x + slotPadding,
                                indentation + slotWidth + slotPadding + 2.0);
    NSRect contentRect = inputRect;

    contentRect.origin.x += leadingInset;
    contentRect.size.width = MAX (0.0, contentRect.size.width - leadingInset);
    return contentRect;
  }
}

@end

@implementation GnomeTheme (MenusAndDataOverrides)

/* Record the grid lines the app asks for (see
   GnomeThemePhase67EffectiveGridMask). Tables decoded from a nib or Gorm file
   go through -setDrawsGrid:, so they keep the grid they were archived with. */
- (void) _overrideNSTableViewMethod_setGridStyleMask: (NSTableViewGridLineStyle)gridType
{
  typedef void (*SetGridIMP)(id, SEL, NSTableViewGridLineStyle);
  SetGridIMP originalIMP = (SetGridIMP)GnomeThemeOriginalMethod (_cmd, self, [NSTableView class]);

  if (originalIMP != NULL)
    {
      originalIMP (self, _cmd, gridType);
    }
  GnomeThemePhase67RecordTableGrid (self, gridType);
  /* Older libs-gui only draws a grid while drawsGrid is set. */
  if (gridType != NSTableViewGridNone && [(NSTableView *)self drawsGrid] == NO)
    {
      [(NSTableView *)self setDrawsGrid: YES];
      GnomeThemePhase67RecordTableGrid (self, gridType);
    }
}

- (void) _overrideNSTableViewMethod_setDrawsGrid: (BOOL)flag
{
  typedef void (*SetDrawsGridIMP)(id, SEL, BOOL);
  SetDrawsGridIMP originalIMP = (SetDrawsGridIMP)GnomeThemeOriginalMethod (_cmd, self, [NSTableView class]);

  if (originalIMP != NULL)
    {
      originalIMP (self, _cmd, flag);
    }
  GnomeThemePhase67RecordTableGrid (self, flag
    ? (NSTableViewSolidVerticalGridLineMask | NSTableViewSolidHorizontalGridLineMask)
    : NSTableViewGridNone);
}

- (void) _overrideNSMenuItemCellMethod_drawKeyEquivalentWithFrame: (NSRect)cellFrame
                                                           inView: (NSView *)controlView
{
  typedef void (*DrawKeyEquivalentIMP)(id, SEL, NSRect, NSView *);
  DrawKeyEquivalentIMP originalIMP = (DrawKeyEquivalentIMP)[[GSTheme theme] overriddenMethod: _cmd
                                                                                           for: self];
  NSMenuItemCell *cell = (NSMenuItemCell *)self;
  NSMenuView *menuView = [cell menuView];
  GnomeTheme *theme = GnomeThemeActivePhase67Theme ();
  BOOL isHorizontal = [menuView isHorizontal];
  BOOL highlighted = [cell isHighlighted];
  NSString *keyEquivalent = nil;
  NSColor *foregroundColor = nil;
  NSRect keyRect;
  NSDictionary *attributes = nil;
  NSMutableParagraphStyle *paragraph = nil;
  NSSize keySize;

  if (theme == nil || isHorizontal || GnomeThemePhase67UsesPopupButtonCellLayout (cell))
    {
      if (originalIMP != NULL)
        {
          originalIMP (self, _cmd, cellFrame, controlView);
        }
      return;
    }

  keyRect = [cell keyEquivalentRectForBounds: cellFrame];
  foregroundColor = GnomeThemePhase67MenuForegroundColor (theme, cell, highlighted);

  if ([[cell menuItem] hasSubmenu])
    {
      NSRect arrowRect = NSMakeRect (NSMaxX (keyRect) - 14.0,
                                     floor (NSMidY (keyRect) - 6.0),
                                     10.0,
                                     12.0);

      GnomeThemePhase67DrawChevron (arrowRect, YES, YES, foregroundColor);
      return;
    }

  keyEquivalent = GnomeThemePhase67KeyEquivalentString (cell);
  if ([keyEquivalent length] == 0)
    {
      if (originalIMP != NULL)
        {
          originalIMP (self, _cmd, cellFrame, controlView);
        }
      return;
    }

  paragraph = AUTORELEASE ([[NSMutableParagraphStyle alloc] init]);
  [paragraph setAlignment: NSRightTextAlignment];
  attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                  GnomeThemePhase67MenuShortcutFont (theme), NSFontAttributeName,
                  foregroundColor, NSForegroundColorAttributeName,
                  paragraph, NSParagraphStyleAttributeName,
                  nil];
  keySize = [keyEquivalent sizeWithAttributes: attributes];
  keyRect.origin.y = floor (NSMidY (keyRect) - (keySize.height / 2.0));
  keyRect.size.height = ceil (keySize.height);
  [keyEquivalent drawInRect: keyRect withAttributes: attributes];
}

- (CGFloat) _overrideNSMenuItemCellMethod_stateImageWidth
{
  typedef CGFloat (*StateImageWidthIMP)(id, SEL);
  StateImageWidthIMP originalIMP = (StateImageWidthIMP)[[GSTheme theme] overriddenMethod: _cmd
                                                                                      for: self];
  NSMenuItemCell *cell = (NSMenuItemCell *)self;
  CGFloat originalWidth = (originalIMP != NULL) ? originalIMP (self, _cmd) : 0.0;

  if ([[cell menuView] isHorizontal] || GnomeThemePhase67UsesPopupButtonCellLayout (cell))
    {
      return originalWidth;
    }

  return MAX (originalWidth, GnomeThemePhase67MenuStateImageWidth (cell));
}

- (CGFloat) _overrideNSMenuItemCellMethod_titleWidth
{
  typedef CGFloat (*TitleWidthIMP)(id, SEL);
  TitleWidthIMP originalIMP = (TitleWidthIMP)[[GSTheme theme] overriddenMethod: _cmd
                                                                           for: self];
  NSMenuItemCell *cell = (NSMenuItemCell *)self;
  CGFloat originalWidth = (originalIMP != NULL) ? originalIMP (self, _cmd) : 0.0;

  if ([[cell menuView] isHorizontal] || GnomeThemePhase67UsesPopupButtonCellLayout (cell))
    {
      return originalWidth;
    }

  /* titleRectForBounds insets the drawable area by 1pt on the left and caps
     the right edge at the key-equivalent column, which leaves the widest
     item of a vertical menu exactly 1pt short of its measured width and
     makes drawInRect: word-wrap the final word out of view.  Reserve extra
     room so the widest title always fits. */
  return originalWidth + 6.0;
}

- (CGFloat) _overrideNSMenuItemCellMethod_keyEquivalentWidth
{
  typedef CGFloat (*KeyEquivalentWidthIMP)(id, SEL);
  KeyEquivalentWidthIMP originalIMP = (KeyEquivalentWidthIMP)[[GSTheme theme] overriddenMethod: _cmd
                                                                                            for: self];
  NSMenuItemCell *cell = (NSMenuItemCell *)self;
  GnomeTheme *theme = GnomeThemeActivePhase67Theme ();
  CGFloat originalWidth = (originalIMP != NULL) ? originalIMP (self, _cmd) : 0.0;

  if ([[cell menuView] isHorizontal] || GnomeThemePhase67UsesPopupButtonCellLayout (cell))
    {
      return originalWidth;
    }

  return MAX (originalWidth, GnomeThemePhase67MenuKeyEquivalentWidth (cell, theme));
}

- (NSRect) _overrideNSMenuItemCellMethod_stateImageRectForBounds: (NSRect)cellFrame
{
  typedef NSRect (*StateRectIMP)(id, SEL, NSRect);
  StateRectIMP originalIMP = (StateRectIMP)[[GSTheme theme] overriddenMethod: _cmd for: self];
  NSMenuItemCell *cell = (NSMenuItemCell *)self;
  NSMenuView *menuView = [cell menuView];
  NSRect rect = (originalIMP != NULL) ? originalIMP (self, _cmd, cellFrame) : cellFrame;

  if ([menuView isHorizontal] || GnomeThemePhase67UsesPopupButtonCellLayout (cell))
    {
      return rect;
    }

  rect.origin.x = cellFrame.origin.x + [menuView stateImageOffset];
  rect.size.width = MAX ([menuView stateImageWidth], GnomeThemePhase67MenuStateImageWidth (cell));
  return rect;
}

- (NSRect) _overrideNSMenuItemCellMethod_keyEquivalentRectForBounds: (NSRect)cellFrame
{
  typedef NSRect (*KeyRectIMP)(id, SEL, NSRect);
  KeyRectIMP originalIMP = (KeyRectIMP)[[GSTheme theme] overriddenMethod: _cmd for: self];
  NSMenuItemCell *cell = (NSMenuItemCell *)self;
  NSMenuView *menuView = [cell menuView];
  NSRect rect = (originalIMP != NULL) ? originalIMP (self, _cmd, cellFrame) : cellFrame;

  if ([menuView isHorizontal] || GnomeThemePhase67UsesPopupButtonCellLayout (cell))
    {
      return rect;
    }

  rect.origin.x = cellFrame.origin.x + [menuView keyEquivalentOffset];
  rect.size.width = [menuView keyEquivalentWidth];
  return rect;
}

- (NSRect) _overrideNSMenuItemCellMethod_titleRectForBounds: (NSRect)cellFrame
{
  typedef NSRect (*TitleRectIMP)(id, SEL, NSRect);
  TitleRectIMP originalIMP = (TitleRectIMP)[[GSTheme theme] overriddenMethod: _cmd for: self];
  NSMenuItemCell *cell = (NSMenuItemCell *)self;
  NSMenuView *menuView = [cell menuView];
  NSRect rect = (originalIMP != NULL) ? originalIMP (self, _cmd, cellFrame) : cellFrame;
  CGFloat leftInset = [menuView imageAndTitleOffset] + 1.0;
  CGFloat rightEdge = NSMaxX (cellFrame) - 10.0;
  CGFloat keyWidth = [menuView keyEquivalentWidth];

  if ([menuView isHorizontal]
    || [[cell menuItem] isSeparatorItem]
    || GnomeThemePhase67UsesPopupButtonCellLayout (cell))
    {
      return rect;
    }

  if (keyWidth > 0.0)
    {
      rightEdge = MIN (rightEdge,
                       cellFrame.origin.x + [menuView keyEquivalentOffset] - 8.0);
    }

  rect.origin.x = MAX (rect.origin.x, cellFrame.origin.x + leftInset);
  rect.size.width = MAX (0.0, rightEdge - rect.origin.x);
  return rect;
}

- (void) _overrideNSMenuItemCellMethod_drawStateImageWithFrame: (NSRect)cellFrame
                                                        inView: (NSView *)controlView
{
  typedef void (*DrawStateImageIMP)(id, SEL, NSRect, NSView *);
  DrawStateImageIMP originalIMP = (DrawStateImageIMP)[[GSTheme theme] overriddenMethod: _cmd
                                                                                    for: self];
  NSMenuItemCell *cell = (NSMenuItemCell *)self;
  NSMenuItem *item = [cell menuItem];
  GnomeTheme *theme = GnomeThemeActivePhase67Theme ();
  BOOL isHorizontal = [[cell menuView] isHorizontal];
  NSInteger state = [item state];
  BOOL highlighted = [cell isHighlighted];
  NSColor *color = nil;
  NSRect stateRect;

  if (theme == nil
    || isHorizontal
    || item == nil
    || GnomeThemePhase67UsesPopupButtonCellLayout (cell)
    || (state != NSOnState && state != NSMixedState))
    {
      if (originalIMP != NULL)
        {
          originalIMP (self, _cmd, cellFrame, controlView);
        }
      return;
    }

  if (GnomeThemePhase67MenuItemUsesDefaultStateImage (item, state) == NO)
    {
      if (originalIMP != NULL)
        {
          originalIMP (self, _cmd, cellFrame, controlView);
        }
      return;
    }

  stateRect = NSInsetRect ([cell stateImageRectForBounds: cellFrame], 1.0, 2.0);

  if ([item isEnabled] == NO)
    {
      color = GnomeThemePhase67Color (theme,
                                      @"disabledControlTextColor",
                                      [NSColor disabledControlTextColor]);
    }
  else if (highlighted)
    {
      color = GnomeThemePhase67Color (theme,
                                      @"selectedMenuItemTextColor",
                                      [NSColor selectedMenuItemTextColor]);
    }
  else
    {
      color = GnomeThemePhase67Color (theme,
                                      @"selectedControlColor",
                                      [NSColor selectedControlColor]);
    }

  if (state == NSMixedState)
    {
      GnomeThemePhase67DrawMenuMixedMark (stateRect, color);
    }
  else
    {
      GnomeThemePhase67DrawMenuCheckmark (stateRect, color);
    }

  (void)controlView;
}

@end
