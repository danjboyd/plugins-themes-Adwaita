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

1. An opt-in setting, e.g. `GnomeThemeWindowDecorations = headerbar`
   (user default, then Info.plist, like the others), documented to be used
   with `GSX11HandlesWindowDecorations NO`. First find out whether the theme
   can set the backend flag itself: the backend reads it when the display
   server is created (`NSApplication`, around `libs-gui/Source/NSApplication.m:894`),
   probably before the theme's defaults domain exists. If it can't, the
   user or app sets both.
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
