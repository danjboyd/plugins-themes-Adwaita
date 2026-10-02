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

/* X11 only, and kept to this file so Xlib's names stay out of the rest of
   the theme. The display and the windows' X ids come from GSDisplayServer's
   public -serverDevice and -windowDevice:, which the X11 backend answers
   with its Display and each window's client window. The messages are the
   ones GTK sends (gdk/x11/gdksurface-x11.c). */

#import "GnomeThemeWindowManager.h"

#import <GNUstepGUI/GSDisplayServer.h>

#include <X11/Xlib.h>
#include <X11/Xatom.h>

/* EWMH _NET_WM_STATE actions, and the source indication for a request from
   an application acting for the user. */
enum
{
  GnomeThemeStateRemove = 0,
  GnomeThemeStateAdd = 1,
  GnomeThemeStateToggle = 2,
  GnomeThemeSourceApplication = 1
};

/* The display, when GNUstep's backend is the X11 one. (The Wayland
   backend's -serverDevice is a wl_display.) */
static Display *
GnomeThemeX11Display(void)
{
  GSDisplayServer *server = GSCurrentServer ();
  Class x11Server = NSClassFromString (@"XGServer");

  if (server == nil || x11Server == Nil || [server isKindOfClass: x11Server] == NO)
    {
      return NULL;
    }
  return (Display *)[server serverDevice];
}

static Window
GnomeThemeX11Window(NSWindow *window)
{
  if ([window windowNumber] <= 0)
    {
      return None;
    }
  return (Window)[GSCurrentServer () windowDevice: [window windowNumber]];
}

/* Whether the window manager lists `name` in _NET_SUPPORTED. Read each
   time: the window manager can be replaced while the app runs, and this
   is asked once per press. */
static BOOL
GnomeThemeX11Supports(Display *display, const char *name)
{
  Atom supported = XInternAtom (display, "_NET_SUPPORTED", False);
  Atom wanted = XInternAtom (display, name, False);
  Atom type;
  int format;
  unsigned long count, remaining;
  unsigned char *data = NULL;
  BOOL found = NO;

  if (XGetWindowProperty (display, DefaultRootWindow (display), supported, 0, 4096, False, XA_ATOM,
                          &type, &format, &count, &remaining, &data) == Success && data != NULL)
    {
      Atom *atoms = (Atom *)data;
      unsigned long i;

      for (i = 0; i < count && found == NO; i++)
        {
          found = (atoms[i] == wanted);
        }
      XFree (data);
    }
  return found;
}

static void
GnomeThemeX11SendToRoot(Display *display, Window window, const char *type, long l0, long l1, long l2, long l3,
                        long l4)
{
  XEvent event;

  memset (&event, 0, sizeof (event));
  event.xclient.type = ClientMessage;
  event.xclient.window = window;
  event.xclient.message_type = XInternAtom (display, type, False);
  event.xclient.format = 32;
  event.xclient.data.l[0] = l0;
  event.xclient.data.l[1] = l1;
  event.xclient.data.l[2] = l2;
  event.xclient.data.l[3] = l3;
  event.xclient.data.l[4] = l4;
  XSendEvent (display, DefaultRootWindow (display), False,
              SubstructureRedirectMask | SubstructureNotifyMask, &event);
  XFlush (display);
}

/* The pointer, in root window coordinates, and the X number of the
   button held down (0 when none is). */
static BOOL
GnomeThemeX11Pointer(Display *display, int *x, int *y, int *button)
{
  Window root, child;
  int windowX, windowY;
  unsigned int mask;
  unsigned int masks[] = { Button1Mask, Button2Mask, Button3Mask, Button4Mask, Button5Mask };
  int i;

  if (XQueryPointer (display, DefaultRootWindow (display), &root, &child, x, y,
                     &windowX, &windowY, &mask) == False)
    {
      return NO;
    }
  *button = 0;
  for (i = 0; i < 5 && *button == 0; i++)
    {
      if (mask & masks[i])
        {
          *button = i + 1;
        }
    }
  return YES;
}

/* Motif hints (MwmUtil.h). */
enum
{
  GnomeThemeMwmHintsFunctions = 1 << 0,
  GnomeThemeMwmHintsDecorations = 1 << 1,
  GnomeThemeMwmFuncResize = 1 << 1,
  GnomeThemeMwmFuncMove = 1 << 2,
  GnomeThemeMwmFuncMinimize = 1 << 3,
  GnomeThemeMwmFuncMaximize = 1 << 4,
  GnomeThemeMwmFuncClose = 1 << 5
};

BOOL
GnomeThemeWindowManagerAllowFunctions(NSWindow *window)
{
  Display *display = GnomeThemeX11Display ();
  Window xwindow = display != NULL ? GnomeThemeX11Window (window) : None;
  NSUInteger style = [window styleMask];
  long hints[5] = { GnomeThemeMwmHintsFunctions | GnomeThemeMwmHintsDecorations, 0, 0, 0, 0 };

  if (xwindow == None || (style & (NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask
                                   | NSResizableWindowMask | NSDocModalWindowMask)) == 0)
    {
      return NO;
    }
  hints[1] = GnomeThemeMwmFuncMove;
  if (style & NSClosableWindowMask)
    {
      hints[1] |= GnomeThemeMwmFuncClose;
    }
  if (style & NSMiniaturizableWindowMask)
    {
      hints[1] |= GnomeThemeMwmFuncMinimize;
    }
  if (style & NSResizableWindowMask)
    {
      hints[1] |= GnomeThemeMwmFuncResize | GnomeThemeMwmFuncMaximize;
    }
  /* hints[2], the decorations: none, the header bar draws them. */
  XChangeProperty (display, xwindow, XInternAtom (display, "_MOTIF_WM_HINTS", False),
                   XInternAtom (display, "_MOTIF_WM_HINTS", False), 32, PropModeReplace,
                   (unsigned char *)hints, 5);
  XFlush (display);
  return YES;
}

BOOL
GnomeThemeWindowManagerMoveResize(NSWindow *window, GnomeThemeMoveResizeDirection direction)
{
  Display *display = GnomeThemeX11Display ();
  Window xwindow = display != NULL ? GnomeThemeX11Window (window) : None;
  int x, y, button;

  /* The window manager follows the pointer only while the button named in
     the request is held down, so name the one the X server says is down.
     (NSEvent's -buttonNumber can't say: libs-back 0.32 gives the X number,
     master since b037ebf AppKit's, where the left button is 0.) */
  if (xwindow == None || GnomeThemeX11Supports (display, "_NET_WM_MOVERESIZE") == NO
    || GnomeThemeX11Pointer (display, &x, &y, &button) == NO || button == 0)
    {
      return NO;
    }
  /* The press's implicit grab would keep the pointer from the window
     manager. */
  XUngrabPointer (display, CurrentTime);
  GnomeThemeX11SendToRoot (display, xwindow, "_NET_WM_MOVERESIZE", x, y, direction, button,
                           GnomeThemeSourceApplication);
  return YES;
}

BOOL
GnomeThemeWindowManagerToggleMaximized(NSWindow *window)
{
  Display *display = GnomeThemeX11Display ();
  Window xwindow = display != NULL ? GnomeThemeX11Window (window) : None;

  if (xwindow == None || GnomeThemeX11Supports (display, "_NET_WM_STATE_MAXIMIZED_VERT") == NO
    || GnomeThemeX11Supports (display, "_NET_WM_STATE_MAXIMIZED_HORZ") == NO)
    {
      return NO;
    }
  GnomeThemeX11SendToRoot (display, xwindow, "_NET_WM_STATE", GnomeThemeStateToggle,
                           XInternAtom (display, "_NET_WM_STATE_MAXIMIZED_VERT", False),
                           XInternAtom (display, "_NET_WM_STATE_MAXIMIZED_HORZ", False),
                           GnomeThemeSourceApplication, 0);
  return YES;
}

BOOL
GnomeThemeWindowManagerShowWindowMenu(NSWindow *window)
{
  Display *display = GnomeThemeX11Display ();
  Window xwindow = display != NULL ? GnomeThemeX11Window (window) : None;
  int x, y, button;

  if (xwindow == None || GnomeThemeX11Supports (display, "_GTK_SHOW_WINDOW_MENU") == NO
    || GnomeThemeX11Pointer (display, &x, &y, &button) == NO)
    {
      return NO;
    }
  XUngrabPointer (display, CurrentTime);
  /* The input device (0: the core pointer), then the root position. */
  GnomeThemeX11SendToRoot (display, xwindow, "_GTK_SHOW_WINDOW_MENU", 0, x, y, 0, 0);
  return YES;
}

BOOL
GnomeThemeWindowManagerShadowExtents(NSWindow *window, CGFloat extents[4])
{
  Display *display = GnomeThemeX11Display ();
  Window xwindow = display != NULL ? GnomeThemeX11Window (window) : None;
  Atom type;
  int format;
  unsigned long count, remaining;
  unsigned char *data = NULL;
  BOOL shadow = NO;
  int i;

  for (i = 0; i < 4; i++)
    {
      extents[i] = 0.0;
    }
  if (xwindow == None)
    {
      return NO;
    }
  if (XGetWindowProperty (display, xwindow, XInternAtom (display, "_GTK_FRAME_EXTENTS", False), 0, 4, False,
                          XA_CARDINAL, &type, &format, &count, &remaining, &data) == Success && data != NULL)
    {
      /* Present even while the extents are 0 (maximised or tiled): the
         window then has neither shadow nor border, as libadwaita's. */
      shadow = type == XA_CARDINAL;
      for (i = 0; shadow && i < 4 && (unsigned long)i < count; i++)
        {
          extents[i] = ((unsigned long *)data)[i];
        }
      XFree (data);
    }
  return shadow;
}

BOOL
GnomeThemeWindowManagerHasShadow(NSWindow *window)
{
  CGFloat extents[4];

  return GnomeThemeWindowManagerShadowExtents (window, extents);
}

BOOL
GnomeThemeWindowManagerIsMaximized(NSWindow *window, BOOL *known)
{
  Display *display = GnomeThemeX11Display ();
  Window xwindow = display != NULL ? GnomeThemeX11Window (window) : None;
  Atom vertical, horizontal, type;
  int format;
  unsigned long count, remaining;
  unsigned char *data = NULL;
  BOOL hasVertical = NO, hasHorizontal = NO;

  *known = NO;
  if (xwindow == None || GnomeThemeX11Supports (display, "_NET_WM_STATE_MAXIMIZED_VERT") == NO)
    {
      return NO;
    }
  vertical = XInternAtom (display, "_NET_WM_STATE_MAXIMIZED_VERT", False);
  horizontal = XInternAtom (display, "_NET_WM_STATE_MAXIMIZED_HORZ", False);
  if (XGetWindowProperty (display, xwindow, XInternAtom (display, "_NET_WM_STATE", False), 0, 64, False, XA_ATOM,
                          &type, &format, &count, &remaining, &data) == Success)
    {
      *known = YES;
      if (data != NULL)
        {
          Atom *atoms = (Atom *)data;
          unsigned long i;

          for (i = 0; i < count; i++)
            {
              hasVertical = hasVertical || atoms[i] == vertical;
              hasHorizontal = hasHorizontal || atoms[i] == horizontal;
            }
          XFree (data);
        }
    }
  return hasVertical && hasHorizontal;
}
