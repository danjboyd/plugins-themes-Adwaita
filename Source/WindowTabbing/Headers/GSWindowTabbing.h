/* GSWindowTabbing.h: Apple's NSWindow tabbing API for GNUstep, and the
   GSTheme methods that draw the tab bar.

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

#ifndef _GSWindowTabbing_h_INCLUDE
#define _GSWindowTabbing_h_INCLUDE

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSTheme.h>

/* libs-gui defines GS_HAS_WINDOW_TABBING once it implements the API
   itself; this code then declares and installs nothing. */
#ifndef GS_HAS_WINDOW_TABBING

typedef enum
{
  NSWindowTabbingModeAutomatic = 0,
  NSWindowTabbingModePreferred = 1,
  NSWindowTabbingModeDisallowed = 2
} NSWindowTabbingMode;

typedef enum
{
  NSWindowUserTabbingPreferenceManual = 0,
  NSWindowUserTabbingPreferenceAlways = 1,
  NSWindowUserTabbingPreferenceInFullScreen = 2
} NSWindowUserTabbingPreference;

typedef NSString *NSWindowTabbingIdentifier;

@class NSWindowTabGroup;

/* One window's tab: what the tab bar shows for it. */
@interface NSWindowTab : NSObject
{
  NSWindow *_window;
  NSString *_title;
  NSAttributedString *_attributedTitle;
  NSString *_toolTip;
  NSView *_accessoryView;
}
/* The window's title unless set. */
- (NSString *) title;
- (void) setTitle: (NSString *)title;
- (NSAttributedString *) attributedTitle;
- (void) setAttributedTitle: (NSAttributedString *)title;
- (NSString *) toolTip;
- (void) setToolTip: (NSString *)toolTip;
- (NSView *) accessoryView;
- (void) setAccessoryView: (NSView *)view;
@end

/* The windows shown as tabs of one window: only the selected one is on
   screen. */
@interface NSWindowTabGroup : NSObject
{
  NSString *_identifier;
  NSMutableArray *_windows;
  NSWindow *_selectedWindow;
  int _barState;
  BOOL _retainsWindows;
}
- (NSWindowTabbingIdentifier) identifier;
- (NSArray *) windows;
- (NSWindow *) selectedWindow;
- (void) setSelectedWindow: (NSWindow *)window;
- (BOOL) isTabBarVisible;
- (BOOL) isOverviewVisible;
- (void) setOverviewVisible: (BOOL)flag;
- (void) addWindow: (NSWindow *)window;
- (void) insertWindow: (NSWindow *)window atIndex: (NSInteger)index;
- (void) removeWindow: (NSWindow *)window;
@end

@interface NSWindow (GSWindowTabbing)
+ (BOOL) allowsAutomaticWindowTabbing;
+ (void) setAllowsAutomaticWindowTabbing: (BOOL)flag;
+ (NSWindowUserTabbingPreference) userTabbingPreference;
- (NSWindowTabbingMode) tabbingMode;
- (void) setTabbingMode: (NSWindowTabbingMode)mode;
- (NSWindowTabbingIdentifier) tabbingIdentifier;
- (void) setTabbingIdentifier: (NSWindowTabbingIdentifier)identifier;
/* nil unless the window is in a group with other windows. */
- (NSArray *) tabbedWindows;
- (NSWindowTab *) tab;
- (NSWindowTabGroup *) tabGroup;
- (void) addTabbedWindow: (NSWindow *)window ordered: (NSWindowOrderingMode)ordered;
- (IBAction) selectNextTab: (id)sender;
- (IBAction) selectPreviousTab: (id)sender;
- (IBAction) moveTabToNewWindow: (id)sender;
- (IBAction) mergeAllWindows: (id)sender;
- (IBAction) toggleTabBar: (id)sender;
@end

/* Sent along the responder chain by the tab bar's "+" button, which is
   shown only when something responds. */
@interface NSResponder (GSWindowTabbingNewTab)
- (IBAction) newWindowForTab: (id)sender;
@end

#endif /* GS_HAS_WINDOW_TABBING */

/* Where the tab bar goes. */
typedef enum
{
  /* Its own row above the content: below a title or header bar, a menu
     bar and a toolbar. The content shrinks by the bar's height. */
  GSWindowTabBarAboveContent = 0,
  /* Placed by the theme's window decoration (for example in the title
     bar): no row is reserved; the theme asks for the bar's view with
     GSWindowTabBarViewForWindow() and lays it out itself. */
  GSWindowTabBarInTitleBar = 1
} GSWindowTabBarPlacement;

/* A tab's or a button's state, as bits. */
enum
{
  GSWindowTabSelected = 1 << 0,
  GSWindowTabHovered = 1 << 1,
  GSWindowTabPressed = 1 << 2,
  /* The tab bar's window is the key window. */
  GSWindowTabWindowKey = 1 << 3,
  GSWindowTabCloseHovered = 1 << 4,
  GSWindowTabClosePressed = 1 << 5,
  /* The tab's window has unsaved changes. */
  GSWindowTabEdited = 1 << 6,
  GSWindowTabFirst = 1 << 7,
  GSWindowTabLast = 1 << 8,
  /* The tab before this one is selected, hovered or pressed (a theme
     may leave out the separator between them). */
  GSWindowTabPreviousHighlighted = 1 << 9
};
typedef unsigned int GSWindowTabState;

/* The theme's part. GSTheme has a plain default for each, in system
   colours; a theme overrides what it draws differently. Every method
   gets the tab bar's window. */
@interface GSTheme (GSWindowTabbing)
- (CGFloat) windowTabBarHeightForWindow: (NSWindow *)window;
- (GSWindowTabBarPlacement) windowTabBarPlacementForWindow: (NSWindow *)window;
/* Tabs share the bar's width equally, between these limits. */
- (CGFloat) windowTabMinimumWidthForWindow: (NSWindow *)window;
- (CGFloat) windowTabMaximumWidthForWindow: (NSWindow *)window;
/* The "+" button's width at the bar's end (0 for none). */
- (CGFloat) windowTabNewTabButtonWidthForWindow: (NSWindow *)window;
/* Space left free at each end of the bar (default 0), and between two
   tabs and before the "+" button (default 0). */
- (CGFloat) windowTabBarMarginForWindow: (NSWindow *)window;
- (CGFloat) windowTabSpacingForWindow: (NSWindow *)window;
/* A tab's close button, in the tab's rect; NSZeroRect for none in
   that state (it can't then be clicked). */
- (NSRect) windowTabCloseButtonRectForTabRect: (NSRect)tabRect
                                        state: (GSWindowTabState)state
                                       window: (NSWindow *)window;
- (void) drawWindowTabBarBackgroundInRect: (NSRect)rect
                                   window: (NSWindow *)window;
/* One tab, its title included (GSWindowTabFittedTitle() shortens it);
   the close button is drawn after it. */
- (void) drawWindowTab: (NSWindowTab *)tab
                inRect: (NSRect)rect
                 state: (GSWindowTabState)state
                window: (NSWindow *)window;
- (void) drawWindowTabCloseButtonInRect: (NSRect)rect
                                  state: (GSWindowTabState)state
                                 window: (NSWindow *)window;
- (void) drawWindowTabNewTabButtonInRect: (NSRect)rect
                                   state: (GSWindowTabState)state
                                  window: (NSWindow *)window;
@end

/* Installs the API and the theme defaults, for what NSWindow and
   GSTheme don't have already. Call it once, early: a theme from its
   -activate, an app from main() after [NSApplication sharedApplication]
   (GSTheme loads the user's theme, which may need the backend). Later
   calls do nothing. Returns NO if libs-gui already has window tabbing. */
GS_EXPORT BOOL GSWindowTabbingInstall (void);

/* The tab bar's view for a window, for a theme whose placement is
   GSWindowTabBarInTitleBar; nil when the bar is hidden. */
GS_EXPORT NSView *GSWindowTabBarViewForWindow (NSWindow *window);

/* title shortened with an ellipsis at its end to fit width. */
GS_EXPORT NSString *GSWindowTabFittedTitle (NSString *title,
                                            NSDictionary *attributes,
                                            CGFloat width);

#endif /* _GSWindowTabbing_h_INCLUDE */
