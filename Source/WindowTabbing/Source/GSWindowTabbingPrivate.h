/* GSWindowTabbingPrivate.h: what the tab group needs from a window.

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

#ifndef _GSWindowTabbingPrivate_h_INCLUDE
#define _GSWindowTabbingPrivate_h_INCLUDE

#import "../Headers/GSWindowTabbing.h"

/* The tab group sees its windows only through these, so the model can
   be tested with stand-in windows and no display (Tests/model). NSWindow
   has them through GSWindowTabbing.m. */
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
- (void) gsTabShowWithFrame: (NSRect)frame makeKey: (BOOL)makeKey;
/* Takes it off screen while it stays in its group. */
- (void) gsTabHide;
/* The group's windows, selection or bar changed: redraw the bar and
   reserve or release its row. */
- (void) gsTabGroupDidChange;
/* The group a window is in; set by the group. */
- (NSWindowTabGroup *) gsTabGroup;
- (void) gsSetTabGroup: (NSWindowTabGroup *)group;
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
- (void) gsToggleTabBar;
- (void) gsSelectNextTab: (BOOL)forward;
/* The window leaves the group (closed, or moved to a window of its
   own); if it was selected its neighbour takes its place at its frame. */
- (void) gsWindowWillLeave: (id)window;
@end

@interface NSWindowTab (GSWindowTabbingPrivate)
- (id) initWithWindow: (NSWindow *)window;
@end

/* GSWindowTabbing.m */
void GSWindowTabbingSendNewWindowForTab (NSWindow *window);
BOOL GSWindowTabbingCanCreateNewTab (NSWindow *window);
/* GSWindowTabbingTheme.m: adds GSTheme's defaults where it has none. */
void GSWindowTabbingInstallThemeDefaults (void);

#endif
