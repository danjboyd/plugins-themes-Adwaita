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
#import "../Settings/GnomeThemeMetrics.h"
#import "../Adapters/GnomeThemeWindowManager.h"

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSTheme.h>
#import <objc/runtime.h>
#import <math.h>

/* Associated-object key: the grid lines (an NSTableViewGridLineStyle in an
   NSNumber) a table's app asked for, recorded by the -setGridStyleMask: and
   -setDrawsGrid: overrides below. */

/* libadwaita's popover menus (and the libs-back patch's popover corners,
   GSBackPopoverCornerRadius in Info-gnustep.plist). */
static const CGFloat GnomeThemeMenuCornerRadius = 15.0;
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

/* A table colour from the theme's own palette (rowBackgroundColor and
   alternateRowBackgroundColor): -colorNamed:state: only finds colours in
   GSTheme's extra colour list, so tables fell back to the table's
   controlBackgroundColor, #303030 in the dark palette instead of
   libadwaita's view colour (#62). */
static NSColor *
GnomeThemePhase67TableColor(GnomeTheme *theme, NSString *key, NSColor *fallback)
{
  NSColor *color = (theme != nil) ? [[theme colors] colorWithKey: key] : nil;

  return (color != nil) ? color : GnomeThemePhase67Color (theme, key, fallback);
}

/* The colour a table draws its rows on: the palette's row colour unless
   the app gave the table a background of its own. */
static NSColor *
GnomeThemePhase67TableRowColor(GnomeTheme *theme, NSColor *backgroundColor)
{
  if (backgroundColor == nil || [backgroundColor isEqual: [NSColor controlBackgroundColor]])
    {
      return GnomeThemePhase67TableColor (theme, @"rowBackgroundColor",
                                          [NSColor controlBackgroundColor]);
    }
  return backgroundColor;
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

/* NSPopUpButtonCell (an NSMenuItemCell) draws the selected item's title in
   the button through the NSMenuItemCell methods overridden below. The theme's
   pop-up layout (-_overrideNSPopUpButtonCellMethod_drawInteriorWithFrame:)
   expects them to give the whole frame to the title, no state image or key
   equivalent column, and to draw neither. Until the overrides used
   GnomeThemeOriginalMethod() that came from -overriddenMethod:for: finding no
   original for the subclass; now it is explicit, so an upstream fix to that
   lookup can't move pop-up titles (the originals put them about 50pt right). */
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

/* A menu item's shortcut as GTK labels it: Shift, Ctrl, Alt, then the
   key (gtk_accelerator_get_label). An uppercase letter is AppKit's way of
   saying Shift ("O" is Shift+Ctrl+O, as GNUstep matches it), so it gets
   Shift too (#41). */
static NSString *
GnomeThemeMenuItemShortcutLabel(NSMenuItem *item)
{
  NSString *equivalent = [item keyEquivalent];
  NSMutableArray *parts;
  NSUInteger mask;
  NSString *displayKey;

  if (item == nil || [equivalent length] == 0)
    {
      return @"";
    }
  displayKey = GnomeThemePhase67DisplayKeyForEquivalent (equivalent);
  if ([displayKey length] == 0)
    {
      return @"";
    }
  mask = [item keyEquivalentModifierMask];
  if ([equivalent length] == 1 && [equivalent isEqualToString: [equivalent lowercaseString]] == NO
    && [equivalent isEqualToString: [equivalent uppercaseString]])
    {
      mask |= NSShiftKeyMask;
    }
  parts = [NSMutableArray arrayWithCapacity: 4];
  if (mask & NSShiftKeyMask)
    {
      GnomeThemePhase67AddShortcutPart (parts, @"Shift");
    }
  if (mask & (NSCommandKeyMask | NSControlKeyMask))
    {
      GnomeThemePhase67AddShortcutPart (parts, @"Ctrl");
    }
  if (mask & NSAlternateKeyMask)
    {
      GnomeThemePhase67AddShortcutPart (parts, @"Alt");
    }
  [parts addObject: displayKey];
  return [parts componentsJoinedByString: @"+"];
}

static NSString *
GnomeThemePhase67KeyEquivalentString(NSMenuItemCell *cell)
{
  if (GnomeThemePhase67UsesPopupButtonCellLayout (cell))
    {
      return @"";
    }
  return GnomeThemeMenuItemShortcutLabel ([cell menuItem]);
}

/* For QuirkProbe. */
@interface NSMenuItem (GnomeThemeShortcutLabel)
- (NSString *) gnomeThemeShortcutLabel;
@end

@implementation NSMenuItem (GnomeThemeShortcutLabel)
- (NSString *) gnomeThemeShortcutLabel
{
  return GnomeThemeMenuItemShortcutLabel (self);
}
@end

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

/* As libadwaita's popover menus: shortcuts and submenu arrows end 12px
   inside the row (its padding), and the row is inset 4px in the cell (the
   selection), so they end 16px from the cell's right edge. A shortcut
   keeps 12px from the title; an arrow is a 16px box. */
static const CGFloat GnomeThemeMenuTrailingInset = 16.0;
static const CGFloat GnomeThemeMenuShortcutGap = 12.0;
static const CGFloat GnomeThemeMenuArrowBox = 16.0;

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
      return GnomeThemeMenuArrowBox + GnomeThemeMenuTrailingInset;
    }

  keyEquivalent = GnomeThemePhase67KeyEquivalentString (cell);
  if ([keyEquivalent length] == 0)
    {
      return 0.0;
    }

  attributes = [NSDictionary dictionaryWithObject: GnomeThemePhase67MenuShortcutFont (theme)
                                           forKey: NSFontAttributeName];
  keySize = [keyEquivalent sizeWithAttributes: attributes];

  return ceil (keySize.width) + GnomeThemeMenuShortcutGap + GnomeThemeMenuTrailingInset;
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

/* Inline button rows (#42), as GTK's "horizontal-buttons" menu sections
   (GNOME's "- 100% +" zoom row): consecutive items of a vertical menu
   whose representedObject is the same @"GnomeThemeInlineGroup:<name>"
   string share one row, each a flat button with its image (or title).
   Under other themes they stay ordinary items. */
static NSString *const GnomeThemeInlineGroupPrefix = @"GnomeThemeInlineGroup:";
static const CGFloat GnomeThemeInlineButtonWidth = 40.0;
static const CGFloat GnomeThemeInlineRowInset = 4.0;

static NSString *
GnomeThemeInlineGroupName(NSMenuItem *item)
{
  id object = [item representedObject];

  if ([object isKindOfClass: [NSString class]] && [(NSString *)object hasPrefix: GnomeThemeInlineGroupPrefix]
    && [item isSeparatorItem] == NO)
    {
      return object;
    }
  return nil;
}

/* The group of the item at `index` in a vertical menu view (two items or
   more), or NSNotFound. */
static NSRange
GnomeThemeInlineGroupRange(NSMenuView *menuView, NSInteger index)
{
  NSMenu *menu = [menuView menu];
  NSInteger count = [menu numberOfItems];
  NSInteger first = index, last = index;
  NSString *name;

  if ([menuView isHorizontal] || [menu _ownedByPopUp] || index < 0 || index >= count)
    {
      return NSMakeRange (NSNotFound, 0);
    }
  name = GnomeThemeInlineGroupName ((NSMenuItem *)[menu itemAtIndex: index]);
  if (name == nil)
    {
      return NSMakeRange (NSNotFound, 0);
    }
  while (first > 0 && [name isEqualToString: GnomeThemeInlineGroupName ((NSMenuItem *)[menu itemAtIndex: first - 1]) ?: @""])
    {
      first--;
    }
  while (last + 1 < count && [name isEqualToString: GnomeThemeInlineGroupName ((NSMenuItem *)[menu itemAtIndex: last + 1]) ?: @""])
    {
      last++;
    }
  if (last == first)
    {
      return NSMakeRange (NSNotFound, 0);
    }
  return NSMakeRange (first, last - first + 1);
}

/* The width an item of a row wants: a button for an image, else its
   title with some room. */
static CGFloat
GnomeThemeInlineNaturalWidth(NSMenuView *menuView, NSInteger index)
{
  NSMenuItem *item = (NSMenuItem *)[[menuView menu] itemAtIndex: index];
  NSMenuItemCell *cell = [menuView menuItemCellForItemAtIndex: index];
  NSFont *font = [cell font] ?: [NSFont menuFontOfSize: 0];

  if ([item image] != nil)
    {
      return MAX (GnomeThemeInlineButtonWidth, [[item image] size].width + 16.0);
    }
  return ceil ([[item title] sizeWithAttributes: [NSDictionary dictionaryWithObject: font
                                                                             forKey: NSFontAttributeName]].width)
    + 24.0;
}

/* What the whole row wants, inset included. */
static CGFloat
GnomeThemeInlineRowWidth(NSMenuView *menuView, NSRange group)
{
  CGFloat width = 2.0 * GnomeThemeInlineRowInset;
  NSUInteger i;

  for (i = group.location; i < NSMaxRange (group); i++)
    {
      width += GnomeThemeInlineNaturalWidth (menuView, i);
    }
  return width;
}

/* The item's segment of its group's row: each at the width it wants,
   the room left over going to the items between the first and last (the
   label of "- 100% +"), or shared out when there are none; narrowed in
   proportion when the row is short. */
static NSRect
GnomeThemeInlineSegment(NSMenuView *menuView, NSRect row, NSRange group, NSInteger index)
{
  NSRect inner = NSInsetRect (row, GnomeThemeInlineRowInset, 0.0);
  CGFloat widths[group.length];
  CGFloat total = 0.0, spare, x = NSMinX (inner);
  NSUInteger i, middle = group.length > 2 ? group.length - 2 : 0;

  for (i = 0; i < group.length; i++)
    {
      widths[i] = GnomeThemeInlineNaturalWidth (menuView, group.location + i);
      total += widths[i];
    }
  spare = NSWidth (inner) - total;
  for (i = 0; i < group.length; i++)
    {
      if (spare < 0.0)
        {
          widths[i] *= NSWidth (inner) / total;
        }
      else if (middle > 0 && i > 0 && i < group.length - 1)
        {
          widths[i] += spare / middle;
        }
      else if (middle == 0)
        {
          widths[i] += spare / group.length;
        }
    }
  for (i = 0; i < (NSUInteger)(index - (NSInteger)group.location); i++)
    {
      x += widths[i];
    }
  return NSMakeRect (floor (x), NSMinY (row), floor (widths[index - group.location]), NSHeight (row));
}

/* The background rows draw on, for the table a header (or corner) view
   belongs to. */
static NSColor *
GnomeThemePhase67TableBackgroundColor(GnomeTheme *theme, NSTableView *tableView)
{
  return GnomeThemePhase67TableRowColor (theme, [tableView backgroundColor]);
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

/* A menu bar too narrow for its titles (#25): the titles that don't fit
   fold into an overflow button at the bar's end (GNOME's view-more icon),
   whose menu holds them. ☰ stays first. Every window's bar shows the same
   main menu, so the menu itself is left as it is (key equivalents,
   validation and Services keep working): a folded item gets an empty rect,
   which nothing draws or hits, and the overflow menu is a copy made each
   time it opens. */
typedef struct
{
  NSInteger folded;   /* The first folded item, or NSNotFound. */
  NSRect overflow;    /* The overflow button; empty when nothing folds. */
} GnomeThemeMenuBarFold;

/* The bar whose overflow button is pressed or whose menu is open. */
static NSMenuView *GnomeThemeOverflowActiveView = nil;

static GnomeThemeMenuBarFold
GnomeThemeMenuBarFolding(NSMenuView *menuView)
{
  typedef NSRect (*RectIMP)(id, SEL, NSInteger);
  SEL selector = @selector(rectOfItemAtIndex:);
  RectIMP originalIMP = (RectIMP)GnomeThemeOriginalMethod (selector, menuView, [NSMenuView class]);
  GnomeThemeMenuBarFold fold = { NSNotFound, NSZeroRect };
  NSMenu *menu = [menuView menu];
  NSInteger count = [menu numberOfItems];
  NSRect bounds = [menuView bounds];
  NSRect first;
  NSInteger index;
  CGFloat width;

  if (originalIMP == NULL || count == 0 || [menuView isHorizontal] == NO
    || [menu _ownedByPopUp] || GnomeThemeUsesPrimaryMenu ()
    || NSInterfaceStyleForKey (@"NSMenuInterfaceStyle", menuView) != NSWindows95InterfaceStyle)
    {
      return fold;
    }
  first = originalIMP (menuView, selector, 0);
  /* Everything fits with the bar's left padding mirrored at its end. */
  if (NSMaxX (originalIMP (menuView, selector, count - 1)) + NSMinX (first) <= NSMaxX (bounds))
    {
      return fold;
    }
  /* As wide as ☰, at the end of the bar where ☰ goes when all fits. */
  width = GnomeThemeApplicationMenuIconWidth + 2.0 * [menuView horizontalEdgePadding];
  fold.overflow = NSMakeRect (NSMaxX (bounds) - NSMinX (first) - width, NSMinY (first), width, NSHeight (first));
  index = GnomeThemeIsApplicationMenuItem ((NSMenuItem *)[menu itemAtIndex: 0]) ? 1 : 0;
  for (; index < count; index++)
    {
      if (NSMaxX (originalIMP (menuView, selector, index)) > NSMinX (fold.overflow))
        {
          fold.folded = index;
          break;
        }
    }
  if (fold.folded == NSNotFound)
    {
      /* Only ☰, which never folds. */
      fold.overflow = NSZeroRect;
    }
  return fold;
}

/* GNOME's view-more-symbolic: three dots, one above the other. */
static void
GnomeThemeDrawOverflowIcon(NSRect rect, NSColor *color)
{
  NSInteger dot;

  [color set];
  for (dot = -1; dot <= 1; dot++)
    {
      [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect (floor (NSMidX (rect)) - 1.5,
                                                           floor (NSMidY (rect)) - 1.5 + 5.0 * dot,
                                                           3.0, 3.0)] fill];
    }
}

/* A highlighted menu bar title's pill, as for an open menu's title. */
static void
GnomeThemeFillMenuBarPill(GnomeTheme *theme, NSRect cellFrame, NSView *controlView)
{
  NSColor *fillColor = GnomeThemePhase67ViewIsActive (controlView)
    ? GnomeThemePhase67Color (theme,
                              @"secondarySelectedControlColor",
                              [NSColor selectedControlColor])
    : GnomeThemePhase67Color (theme,
                              @"selectedInactiveColor",
                              [NSColor selectedControlColor]);
  NSColor *strokeColor = GnomeThemePhase67Blend (fillColor,
                                                 GnomeThemePhase67Color (theme,
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

/* The folded items, copied: the overflow button's menu. */
static NSMenu *
GnomeThemeMenuBarOverflowMenu(NSMenuView *menuView, GnomeThemeMenuBarFold fold)
{
  NSMenu *menu = [menuView menu];
  NSMenu *overflow = AUTORELEASE ([[NSMenu alloc] initWithTitle: @""]);
  NSInteger index;

  for (index = fold.folded; fold.folded != NSNotFound && index < [menu numberOfItems]; index++)
    {
      NSMenuItem *copy = [(NSMenuItem *)[menu itemAtIndex: index] copy];

      [overflow addItem: copy];
      RELEASE (copy);
    }
  return overflow;
}

BOOL
GnomeThemeMenuBarOverflowMouseDown(NSMenuView *menuView, NSEvent *event)
{
  GnomeThemeMenuBarFold fold = GnomeThemeMenuBarFolding (menuView);
  NSWindow *window = [menuView window];
  NSEvent *current = event;
  BOOL pressed = YES;

  if (NSIsEmptyRect (fold.overflow) || window == nil
    || NSPointInRect ([menuView convertPoint: [event locationInWindow] fromView: nil], fold.overflow) == NO)
    {
      return NO;
    }
  /* As a GTK menu button: pressed while the pointer is on it, and the menu
     opens when the click is released there. */
  GnomeThemeOverflowActiveView = menuView;
  [menuView displayRect: fold.overflow];
  while ([current type] != NSLeftMouseUp)
    {
      BOOL inside;

      current = [window nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask
                                    untilDate: [NSDate distantFuture]
                                       inMode: NSEventTrackingRunLoopMode
                                      dequeue: YES];
      inside = NSPointInRect ([menuView convertPoint: [current locationInWindow] fromView: nil], fold.overflow);
      if (inside != pressed)
        {
          pressed = inside;
          GnomeThemeOverflowActiveView = pressed ? menuView : nil;
          [menuView displayRect: fold.overflow];
        }
    }
  if (pressed)
    {
      NSMenu *overflow = GnomeThemeMenuBarOverflowMenu (menuView, fold);
      NSRect button = [menuView convertRect: fold.overflow toView: nil];

      if ([overflow numberOfItems] > 0)
        {
          /* Under the button, right edges aligned, as the main menu. */
          GnomeThemeTrackMenu (overflow, [window convertBaseToScreen: NSMakePoint (NSMaxX (button), NSMinY (button))],
                               YES);
        }
    }
  GnomeThemeOverflowActiveView = nil;
  [menuView setNeedsDisplayInRect: fold.overflow];
  return YES;
}

/* For QuirkProbe. */
@interface NSMenuView (GnomeThemeMenuBarOverflow)
- (NSRect) gnomeThemeOverflowRect;
- (NSMenu *) gnomeThemeOverflowMenu;
@end

@implementation NSMenuView (GnomeThemeMenuBarOverflow)
- (NSRect) gnomeThemeOverflowRect
{
  return GnomeThemeMenuBarFolding (self).overflow;
}

- (NSMenu *) gnomeThemeOverflowMenu
{
  return GnomeThemeMenuBarOverflowMenu (self, GnomeThemeMenuBarFolding (self));
}
@end

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

      /* The overflow button: the folded titles have no rects, so nothing
         else draws here. */
      {
        NSRect overflow = GnomeThemeMenuBarFolding (menuView).overflow;

        if (NSIsEmptyRect (overflow) == NO)
          {
            if (GnomeThemeOverflowActiveView == menuView)
              {
                GnomeThemeFillMenuBarPill (self, overflow, menuView);
              }
            GnomeThemeDrawOverflowIcon (overflow, [NSColor controlTextColor]);
          }
      }
    }
  else
    {
      fillColor = GnomeThemePhase67Color (self,
                                          @"menuBackgroundColor",
                                          [NSColor controlBackgroundColor]);
      borderColor = GnomeThemePhase67Color (self,
                                            @"menuBorderColor",
                                            [NSColor controlShadowColor]);

      /* libadwaita's popover menus' 15px corners, only on a window with
         an alpha channel: elsewhere the corners outside the curve stay
         unpainted, black under a compositor (menus are borderless, 24-bit
         windows). */
      if ([menuView window] != nil && GnomeThemeWindowManagerHasAlpha ([menuView window]) == NO)
        {
          [fillColor set];
          NSRectFill (bounds);
          [borderColor set];
          NSFrameRectWithWidth (bounds, 1.0);
        }
      else
        {
          GnomeThemePhase67FillAndStrokeRoundedRect (NSInsetRect (bounds, 0.5, 0.5),
                                                     GnomeThemeMenuCornerRadius,
                                                     fillColor,
                                                     borderColor,
                                                     1.0);
        }
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
      GnomeThemeFillMenuBarPill (self, cellFrame, controlView);
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
      /* High contrast outlines the row, as libadwaita's hovered menu
         items (the border colour: text at 50%). */
      BOOL highContrast = [[self settings] highContrastEnabled];

      GnomeThemePhase67FillAndStrokeRoundedRect (NSInsetRect (selectionRect, 0.5, 0.5),
                                                 7.0,
                                                 fillColor,
                                                 highContrast ? GnomeThemePhase67Color (self, @"menuBorderColor",
                                                                                        [NSColor controlShadowColor])
                                                   : nil,
                                                 highContrast ? 1.0 : 0.0);
    }
}

- (void) drawSeparatorItemForMenuItemCell: (NSMenuItemCell *)cell
                                withFrame: (NSRect)cellFrame
                                   inView: (NSView *)controlView
                             isHorizontal: (BOOL)isHorizontal
{
  /* Not -menuSeparatorColor: it is black for in-window (Windows 95 style)
     menus when the theme names no colour. */
  NSColor *separatorColor = [self colorNamed: @"menuSeparatorColor" state: GSThemeNormalState];
  CGFloat inset = [self menuSeparatorInset];
  NSBezierPath *path = [NSBezierPath bezierPath];

  (void)cell;
  (void)controlView;

  /* libadwaita's separator: the text colour at 15% (50% in high
     contrast) over the menu's background, a hairline on a pixel row
     (plugins-themes-Adwaita#11: two rows of mid grey). */
  if (separatorColor == nil)
    {
      NSColor *background = GnomeThemePhase67Color (self,
                                                    @"menuBackgroundColor",
                                                    [NSColor controlBackgroundColor]);
      NSColor *text = GnomeThemePhase67Color (self,
                                              @"controlTextColor",
                                              [NSColor controlTextColor]);

      separatorColor = GnomeThemePhase67Blend (background, text,
                                               [[self settings] highContrastEnabled] ? 0.5 : 0.15);
    }

  if (isHorizontal)
    {
      CGFloat x = floor (NSMidX (cellFrame)) + 0.5;

      [path moveToPoint: NSMakePoint (x, NSMinY (cellFrame) + 5.0)];
      [path lineToPoint: NSMakePoint (x, NSMaxY (cellFrame) - 5.0)];
    }
  else
    {
      CGFloat y = floor (NSMidY (cellFrame)) + 0.5;

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
  NSColor *background = GnomeThemePhase67TableColor (self,
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
  if ([cell alignment] == GnomeThemeCenterTextAlignment ())
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
  NSColor *rowColor = GnomeThemePhase67TableRowColor (self, backgroundColor);
  NSColor *alternateColor = GnomeThemePhase67TableColor (self,
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

/* A menu's window is marked as a popover (NSUtilityWindowMask, which a
   borderless window has no other use for), so a libs-back with the
   popover shadows (GSBackPopoverShadows) gives it libadwaita's popover
   shadow round its rounded corners. Only with the header bar: libs-back
   makes no margins when the window manager draws the decorations. */
- (id) _overrideNSMenuPanelMethod_initWithContentRect: (NSRect)contentRect
                                            styleMask: (NSUInteger)style
                                              backing: (NSBackingStoreType)backing
                                                defer: (BOOL)flag
{
  typedef id (*InitIMP)(id, SEL, NSRect, NSUInteger, NSBackingStoreType, BOOL);
  InitIMP originalIMP = (InitIMP)GnomeThemeOriginalMethod (_cmd, self, NSClassFromString (@"NSMenuPanel"));

  if (style == NSBorderlessWindowMask && GnomeThemeUsesHeaderBar ())
    {
      style |= NSUtilityWindowMask;
    }
  return originalIMP != NULL ? originalIMP (self, _cmd, contentRect, style, backing, flag) : self;
}

/* GNOME puts the main menu button at the end of the header bar. GSTheme keeps
   the application item first in the menu (see -organizeMenu:isHorizontal:),
   so move its rect instead: to the right end of the bar, with the other
   items shifted into its place. Drawing, hit testing, highlighting and
   submenu placement all use these rects. When the items don't all fit (a
   narrow window), it stays first, and the titles that don't fit fold into
   the overflow button (GnomeThemeMenuBarFolding). */
- (NSRect) _overrideNSMenuViewMethod_rectOfItemAtIndex: (NSInteger)index
{
  typedef NSRect (*RectIMP)(id, SEL, NSInteger);
  RectIMP originalIMP = (RectIMP)GnomeThemeOriginalMethod (_cmd, self, [NSMenuView class]);
  NSMenuView *menuView = (NSMenuView *)self;
  NSMenu *menu = [menuView menu];
  NSRect rect = (originalIMP != NULL) ? originalIMP (self, _cmd, index) : NSZeroRect;
  NSRect appRect;
  NSRect lastRect;
  NSRange group = GnomeThemeInlineGroupRange (menuView, index);
  GnomeThemeMenuBarFold fold;

  if (group.location != NSNotFound && originalIMP != NULL)
    {
      NSRect row = (index == (NSInteger)group.location) ? rect : originalIMP (self, _cmd, group.location);

      return GnomeThemeInlineSegment (menuView, row, group, index);
    }
  if ([menuView isHorizontal] == NO || originalIMP == NULL)
    {
      return rect;
    }
  fold = GnomeThemeMenuBarFolding (menuView);
  if (fold.folded != NSNotFound)
    {
      /* Folded: no size, past the bar's end. */
      return (index >= fold.folded) ? NSMakeRect (NSMaxX ([menuView bounds]), NSMinY (rect), 0.0, 0.0) : rect;
    }
  if ([menu numberOfItems] < 2
    || GnomeThemeIsApplicationMenuItem ((NSMenuItem *)[menu itemAtIndex: 0]) == NO)
    {
      return rect;
    }
  appRect = (index == 0) ? rect : originalIMP (self, _cmd, 0);
  lastRect = originalIMP (self, _cmd, [menu numberOfItems] - 1);
  if (NSMaxX (lastRect) + NSMinX (appRect) > NSMaxX ([menuView bounds]))
    {
      return rect;
    }
  if (index == 0)
    {
      /* Mirrors the bar's left padding (the first item's x). */
      rect.origin.x = NSMaxX ([menuView bounds]) - NSMinX (appRect) - NSWidth (appRect);
    }
  else
    {
      rect.origin.x -= NSWidth (appRect);
    }
  return rect;
}

/* An inline group's row is its first item's: the others take no height
   of their own. */
- (CGFloat) _overrideNSMenuViewMethod_heightForItem: (NSInteger)index
{
  typedef CGFloat (*HeightIMP)(id, SEL, NSInteger);
  HeightIMP originalIMP = (HeightIMP)GnomeThemeOriginalMethod (_cmd, self, [NSMenuView class]);
  NSRange group = GnomeThemeInlineGroupRange ((NSMenuView *)self, index);

  if (group.location != NSNotFound && index != (NSInteger)group.location)
    {
      return 0.0;
    }
  return originalIMP != NULL ? originalIMP (self, _cmd, index) : 0.0;
}

/* An item of an inline row: its image (a template one in the text
   colour) or its title, centred in its button. */
- (void) _overrideNSMenuItemCellMethod_drawInteriorWithFrame: (NSRect)cellFrame inView: (NSView *)controlView
{
  typedef void (*DrawIMP)(id, SEL, NSRect, NSView *);
  NSMenuItemCell *cell = (NSMenuItemCell *)self;
  NSMenuView *menuView = [cell menuView];
  NSMenuItem *item = [cell menuItem];
  NSRange group = NSMakeRange (NSNotFound, 0);

  if (menuView != nil && item != nil)
    {
      group = GnomeThemeInlineGroupRange (menuView, [[menuView menu] indexOfItem: item]);
    }
  if (group.location == NSNotFound)
    {
      /* NSPopUpButtonCell reaches this through super. */
      DrawIMP originalIMP = (DrawIMP)GnomeThemeOriginalMethodOfClass (_cmd, [NSMenuItemCell class]);

      if (originalIMP != NULL)
        {
          originalIMP (self, _cmd, cellFrame, controlView);
        }
      return;
    }
  {
    GnomeTheme *theme = GnomeThemeActivePhase67Theme ();
    NSColor *color = GnomeThemePhase67MenuForegroundColor (theme, cell, [cell isHighlighted]);
    NSImage *image = [item image];

    if (image != nil)
      {
        NSSize size = [image size];
        NSRect imageRect = NSMakeRect (floor (NSMidX (cellFrame) - size.width / 2.0),
                                       floor (NSMidY (cellFrame) - size.height / 2.0),
                                       size.width, size.height);

        if (GnomeThemeImageIsTemplate (image))
          {
            image = GnomeThemeTintedImage (image, color);
          }
        [image drawInRect: imageRect
                 fromRect: NSZeroRect
                operation: NSCompositeSourceOver
                 fraction: [item isEnabled] ? 1.0 : 0.5];
      }
    else
      {
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
          [cell font] ?: [NSFont menuFontOfSize: 0], NSFontAttributeName,
          color, NSForegroundColorAttributeName, nil];
        NSString *title = [item title];
        NSSize size = [title sizeWithAttributes: attributes];

        [NSGraphicsContext saveGraphicsState];
        NSRectClip (cellFrame);
        [title drawAtPoint: NSMakePoint (floor (NSMidX (cellFrame) - MIN (size.width, NSWidth (cellFrame)) / 2.0),
                                         floor (NSMidY (cellFrame) - size.height / 2.0))
            withAttributes: attributes];
        [NSGraphicsContext restoreGraphicsState];
      }
  }
}

/* libs-gui asks for an item's rect to redraw it, and while the menu needs
   sizing that sizes the whole menu: each item added to a menu re-measures
   all the others, so filling a 2,500-item font menu measured items millions
   of times (#46). The layout changes once it is sized anyway, so redraw the
   whole view then; sized, redraw just the item. */
- (void) _overrideNSMenuViewMethod_setNeedsDisplayForItemAtIndex: (NSInteger)index
{
  typedef void (*SetNeedsDisplayIMP)(id, SEL, NSInteger);
  SetNeedsDisplayIMP originalIMP = (SetNeedsDisplayIMP)GnomeThemeOriginalMethod (_cmd, self, [NSMenuView class]);
  NSMenuView *menuView = (NSMenuView *)self;

  if ([menuView needsSizing] || originalIMP == NULL)
    {
      [menuView setNeedsDisplay: YES];
      return;
    }
  originalIMP (self, _cmd, index);
}

/* The main menu opens under its button, right edges aligned, as GNOME's
   main-menu popover does; GNUstep lines submenus up on the item's left edge,
   which at the end of the bar would hang past the window. */
- (NSPoint) _overrideNSMenuViewMethod_locationForSubmenu: (NSMenu *)aSubmenu
{
  typedef NSPoint (*LocationIMP)(id, SEL, NSMenu *);
  LocationIMP originalIMP = (LocationIMP)GnomeThemeOriginalMethod (_cmd, self, [NSMenuView class]);
  NSMenuView *menuView = (NSMenuView *)self;
  NSMenu *menu = [menuView menu];
  NSPoint location = (originalIMP != NULL) ? originalIMP (self, _cmd, aSubmenu) : NSZeroPoint;
  NSMenuItem *first = ([menu numberOfItems] > 0) ? (NSMenuItem *)[menu itemAtIndex: 0] : nil;
  NSRect itemRect;
  NSRect submenuFrame;

  if ([menuView isHorizontal] && aSubmenu != nil && [first submenu] == aSubmenu
    && GnomeThemeIsApplicationMenuItem (first)
    && NSMinX ([menuView rectOfItemAtIndex: 0]) > NSMinX ([menuView rectOfItemAtIndex: 1]))
    {
      itemRect = [menuView convertRect: [menuView rectOfItemAtIndex: 0] toView: nil];
      submenuFrame = [[[aSubmenu menuRepresentation] window] frame];
      location.x = [[menuView window] convertBaseToScreen: NSMakePoint (NSMaxX (itemRect), 0.0)].x
        - NSWidth (submenuFrame);
    }
  return location;
}

/* Tables built in code start with GTK's list density: 34pt rows and no
   spacing between cells (GNUstep's defaults are 16pt rows, which clip the
   interface font, and 5x2pt gaps that break up the selection). Apps that set
   their own keep them; tables decoded from a nib or Gorm file get their
   archived values, which are decoded after these defaults. */
- (void) _overrideNSTableViewMethod__initDefaults
{
  typedef void (*InitDefaultsIMP)(id, SEL);
  InitDefaultsIMP originalIMP = (InitDefaultsIMP)GnomeThemeOriginalMethod (_cmd, self, [NSTableView class]);
  GnomeTheme *theme = GnomeThemeActivePhase67Theme ();
  Ivar rowHeight = class_getInstanceVariable ([NSTableView class], "_rowHeight");
  Ivar spacing = class_getInstanceVariable ([NSTableView class], "_intercellSpacing");

  if (originalIMP != NULL)
    {
      originalIMP (self, _cmd);
    }
  /* Set directly: -setRowHeight: tiles, and the table isn't built yet. */
  if (theme != nil && rowHeight != NULL && spacing != NULL)
    {
      *(CGFloat *)((char *)self + ivar_getOffset (rowHeight)) = [[theme metricsForView: (NSView *)self] tableRowHeight];
      *(NSSize *)((char *)self + ivar_getOffset (spacing)) = NSMakeSize (0.0, 0.0);
    }
}

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
  DrawKeyEquivalentIMP originalIMP = (DrawKeyEquivalentIMP)GnomeThemeOriginalMethod (_cmd, self, [NSMenuItemCell class]);
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

  if (GnomeThemePhase67UsesPopupButtonCellLayout (cell))
    {
      return;
    }
  if (theme == nil || isHorizontal)
    {
      if (originalIMP != NULL)
        {
          originalIMP (self, _cmd, cellFrame, controlView);
        }
      return;
    }

  keyRect = [cell keyEquivalentRectForBounds: cellFrame];
  /* Shortcuts and arrows end at the row's padding, not at the cell's edge
     (plugins-themes-Adwaita#10). */
  keyRect.size.width = MAX (0.0, NSMaxX (cellFrame) - GnomeThemeMenuTrailingInset - NSMinX (keyRect));
  foregroundColor = GnomeThemePhase67MenuForegroundColor (theme, cell, highlighted);

  if ([[cell menuItem] hasSubmenu])
    {
      NSRect arrowRect = NSMakeRect (NSMaxX (keyRect) - GnomeThemeMenuArrowBox + 3.0,
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
  [paragraph setAlignment: GnomeThemeRightTextAlignment ()];
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
  StateImageWidthIMP originalIMP = (StateImageWidthIMP)GnomeThemeOriginalMethod (_cmd, self, [NSMenuItemCell class]);
  NSMenuItemCell *cell = (NSMenuItemCell *)self;
  CGFloat originalWidth = 0.0;

  if (GnomeThemePhase67UsesPopupButtonCellLayout (cell))
    {
      return 0.0;
    }
  originalWidth = (originalIMP != NULL) ? originalIMP (self, _cmd) : 0.0;
  if ([[cell menuView] isHorizontal])
    {
      return originalWidth;
    }

  return MAX (originalWidth, GnomeThemePhase67MenuStateImageWidth (cell));
}

- (CGFloat) _overrideNSMenuItemCellMethod_titleWidth
{
  typedef CGFloat (*TitleWidthIMP)(id, SEL);
  TitleWidthIMP originalIMP = (TitleWidthIMP)GnomeThemeOriginalMethod (_cmd, self, [NSMenuItemCell class]);
  NSMenuItemCell *cell = (NSMenuItemCell *)self;
  CGFloat originalWidth = 0.0;

  if (GnomeThemePhase67UsesPopupButtonCellLayout (cell))
    {
      return 0.0;
    }
  if ([[cell menuView] isHorizontal] && GnomeThemeIsApplicationMenuItem ([cell menuItem]))
    {
      return GnomeThemeApplicationMenuIconWidth;
    }
  originalWidth = (originalIMP != NULL) ? originalIMP (self, _cmd) : 0.0;
  if ([[cell menuView] isHorizontal])
    {
      return originalWidth;
    }
  /* An inline row: its first item makes the menu as wide as the row. */
  if ([cell menuView] != nil && [cell menuItem] != nil)
    {
      NSMenuView *menuView = [cell menuView];
      NSInteger index = [[menuView menu] indexOfItem: [cell menuItem]];
      NSRange group = GnomeThemeInlineGroupRange (menuView, index);

      if (group.location != NSNotFound)
        {
          return index == (NSInteger)group.location ? GnomeThemeInlineRowWidth (menuView, group) : 0.0;
        }
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
  KeyEquivalentWidthIMP originalIMP = (KeyEquivalentWidthIMP)GnomeThemeOriginalMethod (_cmd, self, [NSMenuItemCell class]);
  NSMenuItemCell *cell = (NSMenuItemCell *)self;
  GnomeTheme *theme = GnomeThemeActivePhase67Theme ();
  CGFloat originalWidth = 0.0;

  if (GnomeThemePhase67UsesPopupButtonCellLayout (cell))
    {
      return 0.0;
    }
  originalWidth = (originalIMP != NULL) ? originalIMP (self, _cmd) : 0.0;
  if ([[cell menuView] isHorizontal])
    {
      return originalWidth;
    }

  return MAX (originalWidth, GnomeThemePhase67MenuKeyEquivalentWidth (cell, theme));
}

- (NSRect) _overrideNSMenuItemCellMethod_stateImageRectForBounds: (NSRect)cellFrame
{
  typedef NSRect (*StateRectIMP)(id, SEL, NSRect);
  StateRectIMP originalIMP = (StateRectIMP)GnomeThemeOriginalMethod (_cmd, self, [NSMenuItemCell class]);
  NSMenuItemCell *cell = (NSMenuItemCell *)self;
  NSMenuView *menuView = [cell menuView];
  NSRect rect;

  if (GnomeThemePhase67UsesPopupButtonCellLayout (cell))
    {
      return cellFrame;
    }
  rect = (originalIMP != NULL) ? originalIMP (self, _cmd, cellFrame) : cellFrame;
  if ([menuView isHorizontal])
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
  KeyRectIMP originalIMP = (KeyRectIMP)GnomeThemeOriginalMethod (_cmd, self, [NSMenuItemCell class]);
  NSMenuItemCell *cell = (NSMenuItemCell *)self;
  NSMenuView *menuView = [cell menuView];
  NSRect rect;

  if (GnomeThemePhase67UsesPopupButtonCellLayout (cell))
    {
      return cellFrame;
    }
  rect = (originalIMP != NULL) ? originalIMP (self, _cmd, cellFrame) : cellFrame;
  if ([menuView isHorizontal])
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
  TitleRectIMP originalIMP = (TitleRectIMP)GnomeThemeOriginalMethod (_cmd, self, [NSMenuItemCell class]);
  NSMenuItemCell *cell = (NSMenuItemCell *)self;
  NSMenuView *menuView = [cell menuView];
  NSRect rect;
  CGFloat leftInset = [menuView imageAndTitleOffset] + 1.0;
  CGFloat rightEdge = NSMaxX (cellFrame) - 10.0;
  CGFloat keyWidth = [menuView keyEquivalentWidth];

  if (GnomeThemePhase67UsesPopupButtonCellLayout (cell))
    {
      return cellFrame;
    }
  rect = (originalIMP != NULL) ? originalIMP (self, _cmd, cellFrame) : cellFrame;
  if ([menuView isHorizontal] || [[cell menuItem] isSeparatorItem])
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
  DrawStateImageIMP originalIMP = (DrawStateImageIMP)GnomeThemeOriginalMethod (_cmd, self, [NSMenuItemCell class]);
  NSMenuItemCell *cell = (NSMenuItemCell *)self;
  NSMenuItem *item = [cell menuItem];
  GnomeTheme *theme = GnomeThemeActivePhase67Theme ();
  BOOL isHorizontal = [[cell menuView] isHorizontal];
  NSInteger state = [item state];
  BOOL highlighted = [cell isHighlighted];
  NSColor *color = nil;
  NSRect stateRect;

  if (GnomeThemePhase67UsesPopupButtonCellLayout (cell))
    {
      return;
    }
  if (theme == nil
    || isHorizontal
    || item == nil
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
      /* The accent as text (accent_color): fills' darker accent would be
         faint on a dark menu. */
      color = GnomeThemePhase67Color (theme,
                                      @"highlightColor",
                                      [NSColor highlightColor]);
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
