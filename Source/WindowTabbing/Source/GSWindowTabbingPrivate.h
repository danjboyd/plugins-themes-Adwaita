/* GSWindowTabbingPrivate.h: window tabbing's private interfaces.

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

#ifndef _GNUstep_H_GSWindowTabbingPrivate
#define _GNUstep_H_GSWindowTabbingPrivate

#import "../Headers/GSWindowTabbing.h"
#import <GNUstepGUI/GSWindowDecorationView.h>

#ifndef GS_HAS_WINDOW_TABBING

@class GSWindowTabBarView;

/* What the tab group needs from a window.  The group talks to its
   windows only through these, so the model can be tested with stand-in
   windows and no display (Tests/gui/NSWindowTabGroup).  NSWindow has
   them through GSWindowTabbingWindow.m. */
@protocol GSWindowTabbable
- (NSRect) frame;
- (NSString *) title;
/* The file the window shows; nil or empty for none (NSWindow's
   -representedFilename). */
- (NSString *) representedFilename;
- (BOOL) isKeyWindow;
- (BOOL) isDocumentEdited;
- (NSWindowTabbingIdentifier) tabbingIdentifier;
/* Puts the window on screen at frame, key if makeKey, as the group's
   selected window. */
- (void) _tabbingShowWithFrame: (NSRect)frame makeKey: (BOOL)makeKey;
/* Takes it off screen while it stays in its group. */
- (void) _tabbingHide;
/* The group's windows, selection or bar changed: redraw the bar and
   reserve or release its row. */
- (void) _tabbingGroupDidChange;
/* The group the window is in, or nil; set by the group. */
- (NSWindowTabGroup *) _tabbingGroup;
- (void) _setTabbingGroup: (NSWindowTabGroup *)group;
@end

/* The tab bar is shown with more than one window, unless toggled. */
enum
{
  GSWindowTabBarAutomatic = 0,
  GSWindowTabBarShown = 1,
  GSWindowTabBarHidden = 2
};

@interface NSWindowTabGroup (GSWindowTabbingPrivate)
- (id) initWithIdentifier: (NSString *)identifier;
/* -[NSWindow toggleTabBar:]. */
- (void) _toggleTabBar;
/* -[NSWindow selectNextTab:] (forward) and -selectPreviousTab:. */
- (void) _selectNextTab: (BOOL)forward;
/* The window leaves the group (closed, or moved to a window of its
   own); if it was selected its neighbour takes its place at its frame. */
- (void) _windowWillLeave: (id)window;
@end

@interface NSWindowTab (GSWindowTabbingPrivate)
- (id) initWithWindow: (NSWindow *)window;
/* The tab's title, tool tip or accessory view changed. */
- (void) _tabDidChange;
@end

/* A window's tabbing state.  Upstream these are instance variables of
   NSWindow; here they live beside each window, in a table kept by
   GSWindowTabbingInstall.m. */
@interface GSWindowTabbingState : NSObject
{
@public
  NSWindowTabbingMode mode;
  NSString *identifier;
  NSWindowTab *tab;
  NSWindowTabGroup *group;
  GSWindowTabBarView *barView;
  /* The window has been ordered in at least once: only a window shown
     for the first time joins a group automatically. */
  BOOL shown;
}
@end

/* The state of window; created when create is YES and it has none.
   GSWindowTabbingInstall.m. */
GSWindowTabbingState *GSWindowTabbingStateForWindow(NSWindow *window,
                                                    BOOL create);
/* Forgets window's state (it is being deallocated). */
void GSWindowTabbingForgetWindow(NSWindow *window);

/* NSWindow's private tabbing methods (GSWindowTabbingWindow.m).  The
   methods NSWindow already has call these: upstream each call is a line
   in that method; here GSWindowTabbingInstall.m wraps the method. */
@interface NSWindow (GSWindowTabbingPrivate) <GSWindowTabbable>
/* From -orderWindow:relativeTo:, before ordering in; YES if tabbing
   handled it (the window was selected in its group, or joined one). */
- (BOOL) _tabbingOrderWindow: (NSWindowOrderingMode)place;
/* From -setTitle:, -setTitleWithRepresentedFilename: and
   -setDocumentEdited:, after them. */
- (void) _tabbingTitleDidChange;
/* From -performKeyEquivalent: and -sendEvent:, first; YES if the event
   was a tab shortcut and has been handled. */
- (BOOL) _tabbingHandleKeyEvent: (NSEvent *)event;
/* From -close, first. */
- (void) _tabbingWillClose;
/* From -validateUserInterfaceItem:, first; YES if item is a tabbing
   action, with its validity in *valid. */
- (BOOL) _tabbingValidateUserInterfaceItem: (id)item valid: (BOOL *)valid;
/* From -dealloc, first. */
- (void) _tabbingDealloc;
/* The height the window gives up for its tab bar (0 for none). */
- (CGFloat) _tabBarReservedHeight;
/* The tab bar's view while the bar is shown, else nil. */
- (GSWindowTabBarView *) _tabBarView;
/* The tab bar's "+" button: is there something to answer
   -newWindowForTab:, and ask it. */
- (BOOL) _tabbingCanCreateNewTab;
- (void) _tabbingCreateNewTab;
@end

/* GSWindowDecorationView's private tabbing method
   (GSWindowTabbingDecorationView.m).  Upstream, -layout calls it at its
   end. */
@interface GSWindowDecorationView (GSWindowTabbingPrivate)
- (void) _layoutTabBar;
@end

#endif /* GS_HAS_WINDOW_TABBING */

#endif /* _GNUstep_H_GSWindowTabbingPrivate */
