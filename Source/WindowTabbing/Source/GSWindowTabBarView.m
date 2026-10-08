/** <title>GSWindowTabBarView</title>

   <abstract>The tab bar of a group of tabbed windows.</abstract>

   Copyright (C) 2026 Daniel Boyd

   Author: Daniel Boyd <danieljboyd@icloud.com>
   Date: 2026

   This file is part of the GNUstep GUI Library.

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
   If not, see <http://www.gnu.org/licenses/> or write to the
   Free Software Foundation, 51 Franklin Street, Fifth Floor,
   Boston, MA 02110-1301, USA.
*/

/* Upstream this is a private libs-gui class as it is (Source/
   GSWindowTabBarView.m). */

#import "GSWindowTabBarView.h"
#import "GSWindowTabbingPrivate.h"

#ifndef GS_HAS_WINDOW_TABBING

@implementation GSWindowTabBarView

- (id) initWithWindow: (NSWindow *)window
{
  if ((self = [super initWithFrame: NSMakeRect(0.0, 0.0, 100.0, 30.0)]) != nil)
    {
      _tabWindow = window;
      _hoveredTab = -1;
      _pressedTab = -1;
      [self setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];
    }
  return self;
}

- (BOOL) isFlipped
{
  return NO;
}

- (NSArray *) tabWindows
{
  return [[_tabWindow tabGroup] windows];
}

- (NSUInteger) numberOfTabs
{
  return [[self tabWindows] count];
}

- (NSRect) newTabButtonRect
{
  CGFloat width;

  if ([_tabWindow _tabbingCanCreateNewTab] == NO)
    {
      return NSZeroRect;
    }
  width = [[GSTheme theme] windowTabNewTabButtonWidthForWindow: _tabWindow];
  if (width <= 0.0)
    {
      return NSZeroRect;
    }
  return NSMakeRect(NSMaxX([self bounds]) - [self margin] - width, 0.0,
                    width, NSHeight([self bounds]));
}

- (CGFloat) margin
{
  return MAX(0.0, [[GSTheme theme] windowTabBarMarginForWindow: _tabWindow]);
}

- (CGFloat) spacing
{
  return MAX(0.0, [[GSTheme theme] windowTabSpacingForWindow: _tabWindow]);
}

/* The bar's width less its margins, the "+" button and the spacing
   between the tabs and before the button, shared by the tabs. */
- (CGFloat) tabWidth
{
  GSTheme *theme = [GSTheme theme];
  NSUInteger count = [self numberOfTabs];
  CGFloat newTab = NSWidth([self newTabButtonRect]);
  CGFloat spacing = [self spacing];
  CGFloat available = NSWidth([self bounds]) - 2.0 * [self margin] - newTab;

  if (newTab > 0.0)
    {
      available -= spacing;
    }
  if (count > 1)
    {
      available -= spacing * (count - 1);
    }
  return GSWindowTabWidth(count, available,
                           [theme windowTabMinimumWidthForWindow: _tabWindow],
                           [theme windowTabMaximumWidthForWindow: _tabWindow]);
}

- (NSRect) rectForTabAtIndex: (NSUInteger)index
{
  CGFloat width = [self tabWidth];

  return NSMakeRect([self margin] + index * (width + [self spacing]), 0.0,
                    width, NSHeight([self bounds]));
}

/* The tab at index is selected, under the pointer or pressed. */
- (BOOL) isTabHighlightedAtIndex: (NSUInteger)index
{
  NSWindow *window = [[self tabWindows] objectAtIndex: index];

  return window == [[_tabWindow tabGroup] selectedWindow]
    || (NSInteger)index == _hoveredTab || (NSInteger)index == _pressedTab;
}

- (GSWindowTabState) stateForTabAtIndex: (NSUInteger)index
{
  NSArray *windows = [self tabWindows];
  NSWindow *window = [windows objectAtIndex: index];
  GSWindowTabState state = 0;

  if (window == [[_tabWindow tabGroup] selectedWindow])
    {
      state |= GSWindowTabSelected;
    }
  if ((NSInteger)index == _hoveredTab)
    {
      state |= GSWindowTabHovered;
      if (_closeHovered)
        {
          state |= GSWindowTabCloseHovered;
        }
    }
  if ((NSInteger)index == _pressedTab)
    {
      state |= GSWindowTabPressed;
      if (_closePressed)
        {
          state |= GSWindowTabClosePressed;
        }
    }
  if ([_tabWindow isKeyWindow])
    {
      state |= GSWindowTabWindowKey;
    }
  if ([window isDocumentEdited])
    {
      state |= GSWindowTabEdited;
    }
  if (index == 0)
    {
      state |= GSWindowTabFirst;
    }
  else if ([self isTabHighlightedAtIndex: index - 1])
    {
      state |= GSWindowTabPreviousHighlighted;
    }
  if (index + 1 == [windows count])
    {
      state |= GSWindowTabLast;
    }
  return state;
}

- (NSRect) closeButtonRectForTabAtIndex: (NSUInteger)index
{
  GSTheme *theme = [GSTheme theme];
  NSRect tabRect = [self rectForTabAtIndex: index];
  GSWindowTabState state = [self stateForTabAtIndex: index];

  return [theme windowTabCloseButtonRectForTabRect: tabRect
                                             state: state
                                            window: _tabWindow];
}

- (NSInteger) tabIndexAtPoint: (NSPoint)point
{
  NSUInteger count = [self numberOfTabs];
  NSUInteger i;

  for (i = 0; i < count; i++)
    {
      if (NSPointInRect(point, [self rectForTabAtIndex: i]))
        {
          return i;
        }
    }
  return -1;
}

- (void) updateToolTips
{
  NSArray *windows = [self tabWindows];
  NSUInteger i;

  [self removeAllToolTips];
  for (i = 0; i < [windows count]; i++)
    {
      NSString *toolTip = [[[windows objectAtIndex: i] tab] toolTip];

      if (toolTip != nil)
        {
          [self addToolTipRect: [self rectForTabAtIndex: i]
                         owner: toolTip
                      userData: NULL];
        }
    }
}

- (void) tabsDidChange
{
  if (_hoveredTab >= (NSInteger)[self numberOfTabs])
    {
      _hoveredTab = -1;
    }
  [self updateToolTips];
  [self setNeedsDisplay: YES];
}

- (void) drawRect: (NSRect)rect
{
  GSTheme *theme = [GSTheme theme];
  NSArray *windows = [self tabWindows];
  NSRect newTab = [self newTabButtonRect];
  NSUInteger i;

  [theme drawWindowTabBarBackgroundInRect: [self bounds] window: _tabWindow];
  for (i = 0; i < [windows count]; i++)
    {
      NSRect tabRect = [self rectForTabAtIndex: i];
      GSWindowTabState state = [self stateForTabAtIndex: i];
      NSRect closeRect;

      if (NSIntersectsRect(tabRect, rect) == NO)
        {
          continue;
        }
      [theme drawWindowTab: [[windows objectAtIndex: i] tab]
                    inRect: tabRect
                     state: state
                    window: _tabWindow];
      closeRect = [theme windowTabCloseButtonRectForTabRect: tabRect
                                                      state: state
                                                     window: _tabWindow];
      if (NSIsEmptyRect(closeRect) == NO)
        {
          [theme drawWindowTabCloseButtonInRect: closeRect
                                          state: state
                                         window: _tabWindow];
        }
    }
  if (NSIsEmptyRect(newTab) == NO)
    {
      GSWindowTabState state = 0;

      if (_newTabHovered)
        {
          state |= GSWindowTabHovered;
        }
      if (_newTabPressed)
        {
          state |= GSWindowTabPressed;
        }
      if ([_tabWindow isKeyWindow])
        {
          state |= GSWindowTabWindowKey;
        }
      [theme drawWindowTabNewTabButtonInRect: newTab
                                       state: state
                                      window: _tabWindow];
    }
}

/* Hover: mouse-moved events only while the pointer is over the bar. */

- (void) updateTrackingRect
{
  if (_tracking)
    {
      [self removeTrackingRect: _trackingTag];
      _tracking = NO;
    }
  if ([self window] != nil)
    {
      _trackingTag = [self addTrackingRect: [self bounds] owner: self
                                  userData: NULL assumeInside: NO];
      _tracking = YES;
    }
}

- (void) viewDidMoveToWindow
{
  [super viewDidMoveToWindow];
  [self updateTrackingRect];
}

- (void) setFrame: (NSRect)frame
{
  [super setFrame: frame];
  [self updateTrackingRect];
  [self updateToolTips];
}

- (void) updateHover: (NSPoint)point
{
  NSInteger tab = [self tabIndexAtPoint: point];
  BOOL closeHovered = (tab >= 0
    && NSPointInRect(point, [self closeButtonRectForTabAtIndex: tab]));
  BOOL newTabHovered = NSPointInRect(point, [self newTabButtonRect]);

  if (tab != _hoveredTab || closeHovered != _closeHovered
    || newTabHovered != _newTabHovered)
    {
      _hoveredTab = tab;
      _closeHovered = closeHovered;
      _newTabHovered = newTabHovered;
      [self setNeedsDisplay: YES];
    }
}

/* GNUstep gives an entered event's location in the view's coordinates,
   Apple's in the window's, so ask the window where the pointer is. */
- (void) mouseEntered: (NSEvent *)event
{
  NSPoint point = [[self window] mouseLocationOutsideOfEventStream];

  _windowAcceptedMouseMoved = [[self window] acceptsMouseMovedEvents];
  [[self window] setAcceptsMouseMovedEvents: YES];
  [self updateHover: [self convertPoint: point fromView: nil]];
}

- (void) mouseMoved: (NSEvent *)event
{
  NSPoint point = [event locationInWindow];

  [self updateHover: [self convertPoint: point fromView: nil]];
}

- (void) mouseExited: (NSEvent *)event
{
  [[self window] setAcceptsMouseMovedEvents: _windowAcceptedMouseMoved];
  [self updateHover: NSMakePoint(-1.0, -1.0)];
}

/* Tracks the button under the mouse until it's released; YES if it's
   released inside rect. */
- (BOOL) trackButtonInRect: (NSRect)rect pressed: (BOOL *)pressed
{
  NSUInteger mask = NSLeftMouseUpMask | NSLeftMouseDraggedMask;
  NSEvent *event;
  NSPoint point;
  BOOL inside = YES;

  *pressed = YES;
  [self setNeedsDisplay: YES];
  while (1)
    {
      event = [NSApp nextEventMatchingMask: mask
                                 untilDate: [NSDate distantFuture]
                                    inMode: NSEventTrackingRunLoopMode
                                   dequeue: YES];
      point = [self convertPoint: [event locationInWindow] fromView: nil];
      inside = NSPointInRect(point, rect);
      if (inside != *pressed)
        {
          *pressed = inside;
          [self setNeedsDisplay: YES];
        }
      if ([event type] == NSLeftMouseUp)
        {
          break;
        }
    }
  *pressed = NO;
  [self setNeedsDisplay: YES];
  return inside;
}

/* The "+" button acts on the release, inside it. */
- (void) pressNewTabButton
{
  if ([self trackButtonInRect: [self newTabButtonRect]
                      pressed: &_newTabPressed])
    {
      [_tabWindow _tabbingCreateNewTab];
    }
}

/* A tab's close button acts on the release, inside it. */
- (void) pressCloseButtonOfTabAtIndex: (NSInteger)tab
{
  NSWindow *window = [[self tabWindows] objectAtIndex: tab];
  NSRect button = [self closeButtonRectForTabAtIndex: tab];
  BOOL released;

  _pressedTab = tab;
  released = [self trackButtonInRect: button pressed: &_closePressed];
  _pressedTab = -1;
  if (released)
    {
      [window performClose: self];
    }
}

/* A press selects its tab at once, as GTK's tabs do; the close and "+"
   buttons act on the release. */
- (void) mouseDown: (NSEvent *)event
{
  NSPoint point = [self convertPoint: [event locationInWindow] fromView: nil];
  NSInteger tab = [self tabIndexAtPoint: point];

  if (NSPointInRect(point, [self newTabButtonRect]))
    {
      [self pressNewTabButton];
    }
  else if (tab >= 0
    && NSPointInRect(point, [self closeButtonRectForTabAtIndex: tab]))
    {
      [self pressCloseButtonOfTabAtIndex: tab];
    }
  else if (tab >= 0)
    {
      [[_tabWindow tabGroup] setSelectedWindow:
        [[self tabWindows] objectAtIndex: tab]];
    }
}

/* A middle click closes the tab, as in GNOME. */
- (void) otherMouseUp: (NSEvent *)event
{
  NSPoint point = [self convertPoint: [event locationInWindow] fromView: nil];
  NSInteger tab = [self tabIndexAtPoint: point];

  if ([event buttonNumber] == 2 && tab >= 0)
    {
      [[[self tabWindows] objectAtIndex: tab] performClose: self];
    }
}

- (BOOL) acceptsFirstMouse: (NSEvent *)event
{
  return YES;
}

- (BOOL) mouseDownCanMoveWindow
{
  return NO;
}

@end

#endif /* GS_HAS_WINDOW_TABBING */
