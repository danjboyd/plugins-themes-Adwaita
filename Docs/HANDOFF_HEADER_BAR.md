# Handoff: an Adwaita header bar drawn by GNUstep

Written 2026-09-25 for whoever picks this up in a new session. It covers the
goal, what's already in place, verified facts about GNUstep's window
decorations (with file and line references), a proposed plan, and the open
questions. Start with "Before you start" and "Testing".

## Goal

GNOME apps have no separate title bar: the window's top row is a header bar
holding the title, the app's main controls, the main menu button (☰) and the
window buttons, with rounded top corners and a shadow. GNUstep apps under
this theme get Mutter's title bar (server-side decorations, drawn by the
window manager), with the app's toolbar or ☰ bar as a second row under it.

Build a header bar that GNUstep draws itself (client-side decorations, CSD):

- one row: centred bold title, window buttons (minimise, maximise, close)
  on the right as GNOME draws them, and ☰ just left of them when the app uses
  the primary menu (`GnomeThemeMenuStyle = primary`);
- later, the window's toolbar items in the same row, as a GNOME header bar
  holds its buttons;
- moving, resizing, double-click to maximise, and window snapping still
  working as well as they do with Mutter's title bar.

The user (Dan) asked for this as the next piece of work. It was discussed as
"option 3" when the primary menu was designed; options 1 and 2 (☰ in the
toolbar, or a slim bar) are built.

## Before you start

- Repo: `~/git/gnustep/plugins-themes-adwaita` (branch `main`, commits up to
  `ad13364` at the time of writing, nothing pushed). Read `README.md` and
  `Docs/IMPROVEMENTS.md` first: the Fixed table records every change and
  why.
- Sibling checkouts used for reading GNUstep's source: `~/git/gnustep/libs-gui`,
  `~/git/gnustep/libs-back`, `~/git/gnustep/apps-gorm`. The installed GNUstep
  is gui 0.32.0 / base 1.31.1 under `/usr/GNUstep`.
- Commit style: code, QuirkProbe and docs as separate commits, messages in
  plain present tense, ending with the Co-Authored-By line. Commit only when
  Dan asks. Install the theme for his apps with
  `make install GNUSTEP_INSTALLATION_DOMAIN=USER`.
- Docs style: short plain sentences, measured facts, no marketing words.
  Code comments explain *why*, as the existing ones do.

## What's already in place

- `Source/Rendering/GnomeThemePrimaryMenu.m`: the primary menu. A
  `GnomeThemePrimaryMenuButton` view draws ☰ as a flat header bar button
  (34px, 6px margins, hover 7% / pressed 16% of the text colour, 6px
  corners) and, when clicked, shows a copy of the main menu right-aligned
  under itself (`GnomeThemeCopyPrimaryMenu`). It is placed in the toolbar
  (narrowed via `-[GSToolbarView setFrame:]`) or in a slim bar that
  replaces the menu bar (`-menuHeightForWindow:`, `-setMenu:forWindow:`).
  A header bar should reuse this button and the copy/show logic.
- `Source/GnomeTheme.m`: `GnomeThemeDrawApplicationMenuIcon()` draws ☰;
  `GnomeThemeUsesPrimaryMenu()` reads the setting (user default, then the
  app's Info.plist).
- Toolbar styling (flat buttons with hover, light bottom edge, icon-only
  default) is in `Source/Rendering/GnomeThemeControls.m`, search for
  `GSToolbarButton`.
- Settings: `Source/Settings/GnomeThemeSettings.m` reads GNOME's GSettings
  (`org.gnome.desktop.interface`) with GIO. The header bar will also want
  `org.gnome.desktop.wm.preferences` (`button-layout`, `titlebar-font`,
  `action-double-click-titlebar`).
- Theme method overrides use GSTheme's `_override<Class>Method_<selector>`
  convention; call the original through `GnomeThemeOriginalMethod()`
  (`Source/GnomeTheme.h`), which also works for subclasses. Overriding an
  inherited method only affects the named class (GSTheme adds the method to
  that class).

## Verified facts about GNUstep's decorations

- Who draws the frame is the backend's choice:
  `-[GSDisplayServer handlesWindowDecorations]`. The X11 backend reads the
  user defaults `GSBackHandlesWindowDecorations`, then
  `GSX11HandlesWindowDecorations` (`libs-back/Source/x11/XGServerWindow.m`,
  around line 1487), when the display server is created at application
  start. Default: the window manager decorates.
- With `-GSX11HandlesWindowDecorations NO`, GNUstep draws its own title bar
  today, in the NeXT style (black bar, round miniaturise and close buttons):
  `Docs/Screenshots/headerbar-baseline.png`, ThemeDemo on a private Xvfb
  display with this theme. The theme doesn't style it yet.
- The decoration view class comes from the theme:
  `-[GSTheme windowDecorator]` (`libs-gui/Source/GSThemeWindow.m:91`)
  returns `GSBackendWindowDecorationView` when the backend decorates and
  `GSStandardWindowDecorationView` otherwise. A theme can override it to
  return its own subclass, e.g. `GnomeThemeHeaderBarDecorationView`.
- `GSStandardWindowDecorationView` (header installed:
  `GNUstepGUI/GSWindowDecorationView.h`, source
  `libs-gui/Source/GSStandardWindowDecorationView.m`) has a title bar rect,
  a *bottom* resize bar only (`resizeModeForPoint:` knows bottom, bottom-left
  and bottom-right), close and miniaturise buttons (no maximise), and moves
  and resizes the window itself in an event loop (`moveWindowStartingWithEvent:`
  calls `setFrameOrigin:` per drag event).
- Its drawing and sizes go through GSTheme: `titlebarHeight`,
  `resizebarHeight`, `titlebarButtonSize`, `titlebarPadding{Left,Right,Top}`,
  `drawTitleBarRect:forStyleMask:state:andTitle:`, `drawWindowBorder:…`
  (`libs-gui/Source/GSThemeDrawing.m` from line 1776),
  `standardWindowButton:forStyleMask:` (`GSThemeWindow.m:39`).
- The menu bar (Win95 style) and toolbar are subviews of the decoration
  view, laid out in `-[GSWindowDecorationView layout]`,
  `addMenuView:`/`removeMenuView`, `addToolbarView:`
  (`libs-gui/Source/GSWindowDecorationView.m`, from line 277 and 460). The
  primary-menu code already hooks these.
- The X11 backend has no support for `_NET_WM_MOVERESIZE` (window-manager
  driven moves and resizes, which give Mutter's snapping, tiling and edge
  resizing), `_GTK_FRAME_EXTENTS` (tells Mutter where the shadow margin is),
  or ARGB (translucent) top-level windows. It does set `_MOTIF_WM_HINTS`
  (`XGServerWindow.m` around line 311) to ask for no WM decorations.
  Everything in this bullet was checked by searching `XGServerWindow.m`.

## Proposed plan

### Phase 1: theme only

1. The opt-in is the backend flag alone (Dan, 2026-09-25): whenever
   GNUstep draws the decorations (`GSX11HandlesWindowDecorations NO`), this
   theme draws the header bar. There is no separate theme setting.

   Checked 2026-09-25: the theme can't set the backend flag itself. The
   theme is loaded (`+[GSTheme initialize]`, then `-[GnomeTheme activate]`)
   from inside the X11 backend's start-up, after the backend has copied the
   default into a file-static `BOOL` (`XGServerWindow.m:79`, read at 1485).
   With `GSX11HandlesWindowDecorations = NO` in the theme's runtime defaults
   domain, ThemeDemo on Xvfb had no title bar (the backend still left
   decorations to the window manager); with `-GSX11HandlesWindowDecorations
   NO` on the command line, GNUstep drew its own. Overriding
   `-[XGServer handlesWindowDecorations]` doesn't help either: the backend
   reads the static directly (lines 224, 341, 1618, 1906 and others), so
   the WM would still decorate. Loading code earlier through
   `GSAppKitUserBundles` would work but needs a second bundle per user.
   Until libs-back changes (phase 2 can add a way for the theme to ask for
   client-side decorations), the user or app sets the backend flag.
2. `-windowDecorator` returns `GnomeThemeHeaderBarDecorationView`, a
   subclass of `GSStandardWindowDecorationView`:
   - height 47 (libadwaita's header bar, measured in the reference renders
     used for the tab work), window background colour, a light
     bottom edge like the toolbar's, bold centred title in the title font
     (`titlebar-font`), dimmed when the window isn't key;
   - window buttons as libadwaita draws them (round, with symbolic icons
     and a grey circle on hover; about 24px circles with 16px icons, from
     memory, so measure them against a libadwaita render), in `button-layout`
     order (GNOME's default `appmenu:close`; Dan's desktop shows
     minimise, maximise, close). Maximise needs its own button (the
     standard view has none) and `-[NSWindow zoom:]`;
   - ☰ in the header bar when the primary menu is on (reuse
     `GnomeThemePrimaryMenuButton`), and then no ☰ bar or toolbar ☰;
   - resizing from every edge and corner, not only the bottom bar: a few
     pixels inside each edge (there's no shadow margin to put them in until
     phase 2), with the matching cursors (the frame-resize cursor images are
     already in `Resources/ThemeImages`);
   - double-click on the title: `action-double-click-titlebar` (default
     toggle-maximise).
3. Check panels, sheets (`GSAlertSheet` is borderless and must stay so),
   utility windows, alerts (the AdwAlertDialog layout in
   `GnomeThemeAlerts.m`), windows without a title, and fullscreen.

### Phase 2: libs-back, for Mutter integration

Upstream changes to `libs-back` (discuss with its maintainers first):

- send `_NET_WM_MOVERESIZE` when the header bar is dragged or an edge is
  pressed, so Mutter moves and resizes (snapping to edges, tiling, the
  resize cursor feedback, Super-drag);
- an ARGB visual for decorated-by-GNUstep windows, a transparent margin with
  a drawn shadow, and `_GTK_FRAME_EXTENTS` so Mutter treats the margin as
  shadow (input goes through it, snapping uses the visible edge); this also
  allows libadwaita's rounded top corners;
- `_NET_WM_STATE` for maximised and tiled states, so the header bar can drop
  the shadow and corners, and the maximise button can show "restore".

### Phase 3: toolbar in the header bar

Move the window's toolbar items into the header bar row (start items on
the left, trailing ones on the right, ☰ last), leaving no separate toolbar
row. NSToolbar has no notion of start and end groups; flexible spaces could
mark the split. Opt-in per app (see Decisions).

## Decisions (Dan, 2026-09-25)

- The header bar becomes the default once it's solid. Until then it stays
  opt-in behind the setting.
- Phases 1 and 2 ship together: build the whole thing before shipping.
  Phase 1 alone (no Mutter snapping, square corners, no shadow) is not a
  release.
- Phase 3 (toolbar items in the header bar row) is opt-in per app.

## Progress (2026-09-25)

Phase 1 is built: `Source/Rendering/GnomeThemeHeaderBar.m`, the ☰ hand-over
in `GnomeThemePrimaryMenu.m`, `button-layout` and
`action-double-click-titlebar` in `GnomeThemeSettings`, nine `header-bar-*`
QuirkProbe checks plus `primary-menu-escape`. `make check-quirks` runs four
configurations (38, 42, 46 and 50 checks, all passing). Dan tried the demo
by hand on GNOME Wayland (menu bar and primary menu) and was happy with it.

Measured and settled (from `Reference/HeaderBar/headerbar_reference.py`,
libadwaita 1.7.6):

- The bar is 46px *including* the 1px border GTK draws round a window
  without a compositor shadow: the border covers the bar's outer pixels, and
  the buttons' 6px margins count from the window's edge. (The "47" above was
  46 plus that border counted twice.)
- libadwaita's bar is flat: the window background, no bottom line.
- Window buttons: 34px, 3px apart, a 24px circle at 10% of the text colour
  (15% hover, 30% pressed) round a 16px icon; icons drawn from Adwaita's
  `window-*-symbolic.svg` paths (restore is one 6px square outline).
- Title: the bold interface font (libadwaita ignores `titlebar-font`),
  centred with its ascent and descent box centred in the bar.
- Not focused (GTK's backdrop state follows keyboard focus, not main-window
  status): text at 60% of the text colour over the background.

Window kinds: panels and utility panels get the bar with a close button; a
window with buttons and no title gets the bar without one; resizable-only
windows keep a border; borderless and `NSFullScreenWindowMask` windows get
neither. Alerts (GSAlertPanel, alone or as a sheet) have no bar, as
AdwAlertDialog: in header bar mode they are created with
`NSDocModalWindowMask` instead of `NSTitledWindowMask` (NSPanel can become
key without a title bar).

GNUstep facts found on the way:

- `-[NSWindow zoom:]` maximises but only goes back through an autosave
  name; the header bar keeps the frame to restore itself.
- `GSWindowDecorationView -layout` puts a menu bar 1pt above the content
  area; the header bar trims it so the bar keeps its 46px.
- NSButton is flipped (the icons turn over for it).
- GNUstep has no `-setStyleMask:` and no `-toggleFullScreen:`.
- In gui 0.32.0 any mouse up ends menu tracking, so a click closed ☰
  straight away; fixed on master (upstream item 8). ☰ opens on the release
  and tracks from a fresh press; Escape closes it.
- QuirkProbe renders come from the window's backing store: call
  `displayIfNeeded` after a state change before rendering. Cursor rects
  post `NSCursorUpdate` events: deliver them before reading
  `[NSCursor currentCursor]`.

Smaller gaps closed afterwards (2026-09-25): the scale factor (offsets in
device pixels; the content origin GNUstep leaves unscaled is corrected),
right-to-left mirroring (matched to a GTK `--rtl` render), GNOME's right,
middle and double-click title bar actions with a window menu, and
libadwaita's high contrast ring and border. `make check-quirks` runs six
configurations (38, 42, 48, 52, then 9 and 9 header bar checks in dark and
high contrast). Left as is: the title and icon colour is the theme's text
colour (#1f1f1f), where libadwaita uses 80% black (#323236); that is a
palette-wide choice.

Phase 2a (2026-09-25), the window manager's part done in the theme on X11:
`Source/Adapters/GnomeThemeWindowManager.m` sends `_NET_WM_MOVERESIZE`
(moves after GTK's 8px drag threshold; resizes on the press),
`_NET_WM_STATE` maximise toggles and `_GTK_SHOW_WINDOW_MENU`, and reads
`_NET_WM_STATE` for the restore icon, all through Xlib on
`-[GSDisplayServer serverDevice]`/`-windowDevice:`. Each call checks the
backend is X11 and the message is in `_NET_SUPPORTED`, else the header bar
does it itself. The decisive fix: libs-back's `_MOTIF_WM_HINTS` for windows
it doesn't decorate allow no functions, so Mutter refused everything; the
header bar rewrites them in `-setWindowNumber:`.

Verified under Mutter (`make check-mutter`, GNOME Shell 48 on a private
Xvfb): allowed actions, maximise and restore by double-click, a move
handed to Mutter taking the window past the screen's edge, a resize from
the right edge; Mutter's window menu on right-click by eye. The request
names the button the X server reports held (`XQueryPointer`), not
`-[NSEvent buttonNumber]`: libs-back 0.32 returns the X number there (left
is 1) and master since b037ebf AppKit's (left is 0), and Mutter declines a
move whose button isn't down. (That mismatch first looked like xdotool not
reaching Mutter on Xvfb; it wasn't.) Drag to the top to maximise didn't
trigger with xdotool; try it by hand.

Warning for test sessions: a GNOME Shell session started for testing runs
gvfs, which mounts plugged-in devices (Dan's phone is always plugged in: it
is the network) under the session's runtime directory. Start such sessions
with `GIO_USE_VFS=local GVFS_DISABLE_FUSE=1 GIO_USE_VOLUME_MONITOR=unix` and
never delete their directories across file systems (the check script's
cleanup shows how).

## Phase 2b in progress (stopped 2026-09-25 evening)

Work in two new git worktrees, on local branches, **nothing committed or
pushed**, nothing installed system-wide:

- `~/git/gnustep/libs-gui-csd` (branch `csd-theme-decorations`, from
  origin/master ff49ac830), built: `Source/obj/libgnustep-gui.so.0.32.0`
  (built with `make ADDITIONAL_OBJCFLAGS=-Wno-error=format-security`).
  Proposal item 4: `GSThemeInstallBackendDefaults()` in GSTheme.m (the
  theme path lookup factored out of `+loadThemeNamed:` into
  `GSThemePathForFileName()`), declared in GSThemePrivate.h, called in
  `-[NSApplication _init]` just before the display server is created. It
  reads `GSBackHandlesWindowDecorations` from the named theme's
  `GSThemeDomain` without loading the theme, and installs it in the
  GSThemeDomain volatile domain unless the user set
  GSBackHandlesWindowDecorations or GSX11HandlesWindowDecorations.
  Verified: with no user setting (isolated defaults, below), ThemeDemo gets
  the header bar from the theme alone with this libs-gui, and none with the
  installed one.
- `~/git/gnustep/libs-back-csd` (branch `csd-header-bar`, from origin/master
  5db2ae7), built: `Source/libgnustep-back-032.bundle`.
  - Item 0: `setWindowHintsForStyle()` keeps the functions for windows the
    gui decorates (decorations 0, functions from the style, plus move).
  - Item 2, the shadow margin: `gswindow_device_t` gains `shadow[4]`
    (left, right, top, bottom), `corner_radius`, `shadow_eligible`. A
    styled window gets a margin of 30/30/24/36 px (measured from
    libadwaita under Mutter) when the gui decorates, `GSBackWindowShadows`
    is YES and a compositing manager owns `_NET_WM_CM_Sn`. Such windows
    get a 32-bit ARGB visual of their own (`argb_visual()`; master's
    `xlibimage.c` RCreateContext always uses the default 24-bit visual, so
    nothing else has alpha). `-_offsets::::for:` returns minus the margin
    when the gui decorates (else `-styleoffsets`), and is used by the
    frame, window-rect and point conversions, `-setWindowdevice:forContext:`
    and `-flushwindowrect::`; the WM hint conversions keep `-styleoffsets`
    (hints use the X window's own origin). `-_updateShadowOf:` sets
    `_GTK_FRAME_EXTENTS` and an XShape input region of the visible part
    (clicks in the margin go through). `-_updateShadowSizeOf:` drops the
    margin while `_NET_WM_STATE` is maximised (both) or fullscreen, or
    `_GTK_EDGE_CONSTRAINTS` has a tiled bit; PropertyNotify on those calls
    it and sends the gui the new frame; ConfigureNotify reshapes the input
    region; Expose copies the margin from the backing store.
  - XGCairoModernSurface keeps a separate shadow image
    (`create_shadow()`: 0.19·e^(−d/10) at the sides, weaker above, a little
    stronger below, following the corner radius) and `-handleExposeRect:`
    copies the backing store through a rounded clip of the visible part
    (`visible_path()`) and the shadow everywhere else, so nothing the gui
    draws can un-round the corners.
- Theme (this repo, uncommitted): `Resources/Info-gnustep.plist`
  GSThemeDomain sets `GSBackHandlesWindowDecorations = NO`,
  `GSBackWindowShadows = YES`, `GSBackWindowCornerRadius = 15`;
  `GnomeThemeWindowManagerHasShadow()` reads `_GTK_FRAME_EXTENTS`, and the
  header bar then paints its 1px border in the window background (the
  shadow's outline is the edge, as in libadwaita). `make check-quirks`
  passes (38, 42, 48, 52, 9, 9).

Verified under Mutter (GNOME Shell on a private Xvfb, `:63`): the X window
is 32-bit, `_GTK_FRAME_EXTENTS` = 30, 30, 24, 36, the visible window sits
where the frame says, the shadow is there (about 18% at the edge, like
libadwaita's) and all four corners are rounded with the shadow following
them.

Not yet tested (next steps, in order):

1. Maximise and restore: the margin should drop to 0 (square corners, the
   window filling the work area) and come back. Also tiling (Super+Left).
2. Moves and resizes handed to Mutter with the margin (xdotool on `:63` as
   in `make check-mutter`), and a click in the margin reaching the window
   behind (input shape).
3. `make check-mutter` against the patched libraries; extend it with
   shadow checks (depth 32, frame extents, a shadow pixel, a rounded
   corner pixel, extents 0 when maximised).
4. Other window kinds with a shadow: panels, alerts (NSDocModalWindowMask
   gets one), sheets, menus and tool tips (borderless: none).
5. Try it on the real desktop (GNOME Wayland, Xwayland), then the style
   pass for upstream (GNU style, ChangeLog entries) and a note in the
   proposal that items 0, 2 and 4 now have patches.

How to run against the patched libraries:

- libs-gui: `LD_LIBRARY_PATH=$HOME/git/gnustep/libs-gui-csd/Source/obj:$LD_LIBRARY_PATH`.
- libs-back: `ln -sfn ~/git/gnustep/libs-back-csd/Source/libgnustep-back-032.bundle
  ~/GNUstep/Library/Bundles/libgnustep-backcsd-032.bundle` and launch with
  `-GSBackend libgnustep-backcsd`; remove the link afterwards (it was
  removed at the end of the session).
- Mutter test session: GNOME Shell `--x11` on a private Xvfb with its own
  D-Bus session, settings in memory, scratch XDG directories and
  `GIO_USE_VFS=local GVFS_DISABLE_FUSE=1 GIO_USE_VOLUME_MONITOR=unix`
  (see `Tests/Scripts/run-mutter-check.sh`; never delete its directories
  across file systems).
- Isolated GNUstep defaults (Dan has `GSX11HandlesWindowDecorations NO` set
  globally): a copy of `/etc/GNUstep/GNUstep.conf` with
  `GNUSTEP_USER_DEFAULTS_DIR` pointing at an empty directory, mode 0600,
  passed as `GNUSTEP_CONFIG_FILE`.

Then phase 3. The proposal to send to libs-back's maintainers
is `Docs/PROPOSAL_LIBS_BACK_CSD.md`.

## Testing

- `make check-quirks` runs `Examples/QuirkProbe` twice (menu bar and primary
  menu) on a private Xvfb display and must stay green (38 and 41 checks at
  the time of writing, plus one KNOWN upstream bug). Add header bar checks
  there: render the decoration view offscreen (see how `saveWindow:named:`
  renders the frame view) and measure; run the probe with
  `QUIRK_PROBE_ARGS="-GSX11HandlesWindowDecorations NO …"`.
- For clicks, send events through `NSApp`/the window inside the probe (see
  `QuirkProbeSendApplicationEvent` and `checkPrimaryMenu`, which uses a timer
  in `NSEventTrackingRunLoopMode` to inspect a menu while it tracks).
  Synthetic X input (xdotool) proved unreliable for GNUstep windows, even on
  Xvfb.
- Do not drive Dan's real GNOME desktop with xdotool. He works on it while
  sessions run; XTest input can't reach GNOME Shell (so it can't undo what it
  starts), and a stray pointer move to the top-left corner opened the
  Activities overview in an earlier session. Use a private `Xvfb :N` display
  and `import -window root` for screenshots. Gorm's and other apps' panels
  hide when the app isn't active, which happens on Dan's desktop because of
  focus-stealing prevention.
- libadwaita references: `Reference/AdwaitaDemo/adwaita_demo.py --screenshot`
  renders pages offscreen; small GTK4/libadwaita scripts rendered the same
  way (Gtk.WidgetPaintable + Gsk.CairoRenderer) give pixel-exact references
  for the header bar, window buttons and spacing. Measure, don't guess: the
  earlier work matched tabs, alerts and rows to the pixel this way.
- Compare against the GNUstep theme (`-GSTheme GNUstep`) to tell theme bugs
  from GNUstep's.

## Deferred, not part of this

- "Design surfaces" in Gorm (WYSIWYG palette and document windows drawn with
  GNOME metrics while Gorm's own panels stay compact): designed but deferred
  until Dan has talked to Gorm's maintainer. Notes: the private
  `+[NSFont _fontWithName:size:role:]` can make a default-size system font at
  GNOME's size that archives identically; Gorm's design windows are
  `GormNSWindow`/`GormNSPanel`, the palette area `GormPaletteView`.
