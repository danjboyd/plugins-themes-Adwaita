/*
   Copyright (C) 2026 Daniel Boyd

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

#import <AppKit/AppKit.h>

/* The window manager's part in the header bar, asked for as GTK asks for
   it on X11 (EWMH and GTK's own messages), so that Mutter moves, resizes
   and maximises GNUstep-decorated windows as it does GTK's: snapping,
   tiling, dragging off screen, Super-drag, its window menu.

   Each call returns NO when it can't ask (the backend isn't X11, or the
   window manager doesn't list the message in _NET_SUPPORTED); the header
   bar then does the job itself. */

/* libs-back's Motif hints for a window it doesn't decorate allow the
   window manager no functions, so Mutter won't move, maximise, minimise
   or close it, even when asked. This keeps "no decorations" and allows
   the functions the window's style has, as libs-back does for windows the
   window manager decorates. Call it once the X window exists. */
BOOL GnomeThemeWindowManagerAllowFunctions(NSWindow *window);

/* _NET_WM_MOVERESIZE directions. */
typedef enum
{
  GnomeThemeMoveResizeTopLeft = 0,
  GnomeThemeMoveResizeTop = 1,
  GnomeThemeMoveResizeTopRight = 2,
  GnomeThemeMoveResizeRight = 3,
  GnomeThemeMoveResizeBottomRight = 4,
  GnomeThemeMoveResizeBottom = 5,
  GnomeThemeMoveResizeBottomLeft = 6,
  GnomeThemeMoveResizeLeft = 7,
  GnomeThemeMoveResizeMove = 8
} GnomeThemeMoveResizeDirection;

/* Hands a move or resize, started by the mouse button held down now, to
   the window manager. It follows the pointer until the button is
   released. */
BOOL GnomeThemeWindowManagerMoveResize(NSWindow *window, GnomeThemeMoveResizeDirection direction);

/* Asks the window manager to maximise the window, or to restore it when
   it is maximised. */
BOOL GnomeThemeWindowManagerToggleMaximized(NSWindow *window);

/* Asks the window manager to show its window menu at the pointer. */
BOOL GnomeThemeWindowManagerShowWindowMenu(NSWindow *window);

/* Whether the window manager has the window maximised; NO in `known` when
   it can't tell. */
BOOL GnomeThemeWindowManagerIsMaximized(NSWindow *window, BOOL *known);
