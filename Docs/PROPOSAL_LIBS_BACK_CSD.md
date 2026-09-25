**Repository:** gnustep/libs-back (and a small part in libs-gui)

**Title:** Proposal: better support for GNUstep-drawn window decorations on X11

Draft, 2026-09-25, for Dan Boyd to send to the libs-back maintainers. Checked
against libs-back master 5db2ae7 (2026-09-11) and libs-gui master ff49ac8.

### Background

With `GSX11HandlesWindowDecorations NO`, GNUstep draws the title bar itself
(`GSStandardWindowDecorationView`), and a theme can replace it through
`-[GSTheme windowDecorator]`. The Adwaita theme
(plugins-themes-adwaita) uses this to draw libadwaita's header bar: title,
window buttons and the app's main menu button in one row, as GNOME apps
have.

The theme also hands moves, resizes, maximising and the window menu to the
window manager, as GTK does, by sending the EWMH and GTK messages itself
through `-[GSDisplayServer serverDevice]` and `-windowDevice:` with Xlib
(Source/Adapters/GnomeThemeWindowManager.m in the theme). Under Mutter that
gives GNUstep windows snapping, tiling, dragging off screen, Super-drag,
Mutter's maximise and its window menu. It needs one workaround for a
libs-back bug (item 0).

What still needs the backend:

- item 0, a bug: the Motif hints of windows GNUstep decorates forbid every
  window manager function;
- item 2, a shadow round the window and rounded top corners;
- item 4, letting a theme turn GNUstep-drawn decorations on.

Items 1 and 3 would still be worth having in libs-back, so that
`GSStandardWindowDecorationView` and other themes get the same behaviour
without Xlib code of their own; the theme's implementation can serve as the
reference. We can write the patches; we'd like to know first whether this
direction is welcome, and which API shapes you'd prefer.

### 0. Motif hints forbid all functions (bug)

With `GSX11HandlesWindowDecorations NO`, `setWindowHintsForStyle()`
(XGServerWindow.m around line 312) sets `_MOTIF_WM_HINTS` with
`MWM_HINTS_FUNCTIONS` and `functions = 0` for every window, not only
borderless ones. That asks for no decorations, which is right, but also
tells the window manager that the window may not be moved, resized,
minimised, maximised or closed. Mutter follows it: `_NET_WM_ALLOWED_ACTIONS`
lists no move, maximise, minimise or close, so `_NET_WM_MOVERESIZE`,
`_NET_WM_STATE` maximise requests, Super-drag and the window menu's
entries all do nothing. (GNUstep's own title bar moves the window with
`XMoveWindow`, which the hints don't restrict, so this went unnoticed.)

GTK sets only `MWM_HINTS_DECORATIONS` with no decorations. Suggested fix:
for a styled window that GNUstep decorates, keep `decorations = 0` and set
the functions from the style mask as the decorated branch already does
(move; close, minimise, resize and maximise as the style allows). The
theme does this after the window is created
(`GnomeThemeWindowManagerAllowFunctions`).

### 1. Window-manager-driven move and resize (`_NET_WM_MOVERESIZE`) (done in the theme)

libs-back sends no `_NET_WM_MOVERESIZE`. A decoration view that gets a press
on its title bar or an edge could hand the drag to the window manager:

```objc
/* GSDisplayServer: ask the window manager to move (edge 8) or resize
   (edges 0-7, EWMH order) the window, starting at a screen point, for the
   given mouse button. Returns NO when the window manager doesn't support
   it, and the caller keeps its own loop. */
- (BOOL) beginMoveResizeWindow: (int)win
                          edge: (int)edge
                       atPoint: (NSPoint)screenPoint
                        button: (int)button;
```

The X11 implementation ungrabs the pointer and sends the EWMH client message
to the root window when `_NET_SUPPORTED` lists `_NET_WM_MOVERESIZE`. The
Wayland backend already does the equivalent (`xdg_toplevel_move` and
`xdg_toplevel_resize` in WaylandServer+Cursor.m); this would give X11 the
same and make it available to decoration views.
`GSStandardWindowDecorationView` would try it first in
`-moveWindowStartingWithEvent:` and `-resizeWindowStartingWithEvent:`, so
every theme benefits.

### 2. A shadow margin (`_GTK_FRAME_EXTENTS`)

A shadow needs a transparent margin outside the window's visible edge, drawn
into, and the window manager told where the visible window is, so that it
snaps and tiles the visible part and passes input through the margin. GTK
does this with an ARGB visual and `_GTK_FRAME_EXTENTS` (left, right, top,
bottom, CARDINAL[4]); Mutter and KWin both honour it.

libs-back creates windows with the default visual and has no
`_GTK_FRAME_EXTENTS`. The existing offset mechanism (frame offsets for
window-manager borders) already separates `NSWindow`'s frame from the X
window's geometry; a margin is the same idea turned outwards. A possible
shape:

- When GNUstep draws the decorations and the screen has a compositing
  manager (`_NET_WM_CM_S<n>` is owned), create top-level windows with a
  32-bit ARGB visual and a margin of N pixels on each side (a user default,
  0 to turn it off).
- Keep `NSWindow`'s frame the visible window; the X window is the frame plus
  the margin, and the backend converts, as it does for the offsets today.
- Set `_GTK_FRAME_EXTENTS` to the margin, and clear it (margin 0) while
  maximised, tiled or fullscreen (item 3).
- Who draws the shadow: either the backend (a blurred rectangle in the
  margin, simplest, no gui change) or the decoration view, if the drawable
  covers the margin. We'd start with the backend drawing it and a theme
  hook for its size and colour.

This is the largest of the four and touches every drawing path, so we'd like
your view on it before starting.

### 3. Window states (`_NET_WM_STATE`) (maximise done in the theme)

libs-back sets `_NET_WM_STATE` for skip-taskbar, sticky and modal, but
doesn't read the maximised, tiled or fullscreen states, and `-zoom:` resizes
the window itself instead of asking the window manager (which then doesn't
know the window is maximised: no restore on drag, no tiling interplay).

- Ask the window manager to maximise and restore with
  `_NET_WM_STATE_MAXIMIZED_VERT`/`_HORZ` client messages (a
  `GSDisplayServer` call used by `-[NSWindow zoom:]` when the window manager
  supports it).
- Read `_NET_WM_STATE` on PropertyNotify and pass maximised, fullscreen and
  the tiled edges (`_NET_WM_STATE_TILED` where supported, Mutter's
  `_GTK_EDGE_CONSTRAINTS` otherwise) to the window, for example as an
  `NSAppKitDefined` event that the decoration view receives.

### 4. Letting a theme ask for GNUstep-drawn decorations

The backend reads `GSBackHandlesWindowDecorations` /
`GSX11HandlesWindowDecorations` in `-[XGServer _setupRootWindow]`
(XGServerWindow.m around line 1582) into a file-static `BOOL`. The theme is
loaded later: its `+initialize` runs from inside the backend's own start-up
(seen in a backtrace), after that read. So a theme that draws its own
decorations can't turn them on; each user or app has to set the flag, and
then gets the theme's decorations only while that theme is in use.

Proposal: a key in the theme bundle's Info.plist, for example
`GSThemeWindowDecorations = client`, that libs-gui reads from the theme named
by the `GSTheme` default before it creates the display server
(`-[NSApplication _init]`, before `+[GSDisplayServer serverWithAttributes:]`)
and passes on (a volatile defaults domain, or a server attribute). An
explicit user default still wins.

### Wayland

The Wayland backend always leaves the decorations to GNUstep
(`-handlesWindowDecorations` returns NO) and already uses `xdg_toplevel_move`,
`xdg_toplevel_resize` and `xdg_surface_set_window_geometry`. This proposal is
about X11, where GNUstep apps run on GNOME today (Xwayland); items 2 and 3
would map to the window geometry and the toplevel's configure states on
Wayland.

### Contact

Dan Boyd (plugins-themes-adwaita). A test program for each item can follow;
the theme's `make check-quirks` already exercises the decoration view with
`-GSX11HandlesWindowDecorations NO`.
