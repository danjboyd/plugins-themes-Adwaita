/* GSWindowTabBarView.h: the tab bar of a group of tabbed windows.

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

#ifndef _GSWindowTabBarView_h_INCLUDE
#define _GSWindowTabBarView_h_INCLUDE

#import <AppKit/AppKit.h>
#import "GSWindowTabbing.h"

/* Each window of a group has one; the selected window's is on screen.
   It lays the tabs out and handles the mouse; GSTheme draws. */
@interface GSWindowTabBarView : NSView
{
  NSWindow *_tabWindow;
  NSInteger _hoveredTab;
  NSInteger _pressedTab;
  BOOL _closeHovered;
  BOOL _closePressed;
  BOOL _newTabHovered;
  BOOL _newTabPressed;
  NSTrackingRectTag _trackingTag;
  BOOL _tracking;
  BOOL _windowAcceptedMouseMoved;
}
- (id) initWithWindow: (NSWindow *)window;
/* The tabs, a title or the selection changed. */
- (void) tabsDidChange;
/* The layout, in the view's coordinates: */
- (NSUInteger) numberOfTabs;
/* The theme's margin at each end and spacing between tabs. */
- (CGFloat) margin;
- (CGFloat) spacing;
- (CGFloat) tabWidth;
- (NSRect) rectForTabAtIndex: (NSUInteger)index;
- (NSRect) closeButtonRectForTabAtIndex: (NSUInteger)index;
/* NSZeroRect when nothing responds to -newWindowForTab:. */
- (NSRect) newTabButtonRect;
- (NSInteger) tabIndexAtPoint: (NSPoint)point;
/* The state the theme draws the tab at index in. */
- (GSWindowTabState) stateForTabAtIndex: (NSUInteger)index;
@end

/* The layout without a view, for tests: count tabs of equal width
   between minimum and maximum share width (the bar's, less its margins,
   the "+" button and the spacing). */
CGFloat GSWindowTabWidth (NSUInteger count, CGFloat width,
                          CGFloat minimum, CGFloat maximum);

#endif
