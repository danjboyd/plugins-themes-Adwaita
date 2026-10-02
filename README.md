# GNUstep Adwaita Theme

`plugins-themes-adwaita` is an Adwaita-targeted theme plugin for GNUstep.

The goal is pragmatic rather than literal pixel-perfect GTK emulation: make
GNUstep applications feel at home on a modern GNOME desktop while staying
inside the GNUstep theme layer wherever possible.

The current priority is forward-looking GNOME integration, not strict backward
compatibility with the appearance of existing GNUstep applications. The main
use case today is making it possible to build new GNUstep apps that feel at
home on GNOME. Backward-compatibility improvements may still happen later, but
they are not the primary design constraint for this release.

## Screenshots

<p>
  <img src="Docs/Screenshots/theme-controls.png" alt="ThemeDemo controls page" width="32%">
  <img src="Docs/Screenshots/theme-text.png" alt="ThemeDemo text inputs page" width="32%">
  <img src="Docs/Screenshots/theme-data.png" alt="ThemeDemo data views page" width="32%">
</p>

## Status

This project should currently be treated as an `0.1.0-alpha1` release.

What is already in place:

- Adwaita-inspired palette, spacing, and control rendering for core widgets
- A GNUstep demo app for side-by-side inspection
- A GTK4/libadwaita reference app for comparison
- GNOME settings integration for fonts and appearance variants

What is still known to be incomplete:

- text-field focus/render parity is not fully resolved yet
- some popup/combo-box interaction details still need manual polish
- visual acceptance is still partly manual rather than fully scripted

## Known Issues

- Focusing a text field can still cause a subtle text rendering change compared
  to the unfocused state.
- Combo-box and popup-menu interaction chrome is substantially improved, but a
  few interaction details still need final polish against the GTK reference.
- The project still relies on manual side-by-side visual review for some
  acceptance decisions.

## Scope

This theme targets stock Adwaita as the visual baseline for GNUstep on GNOME.

It does not currently aim to:

- support arbitrary third-party GTK themes
- reproduce GTK4's rendering architecture
- patch `libs-gui` unless a clear framework blocker remains after theme work
- guarantee that existing GNUstep applications will preserve their prior look
  unchanged under this theme

## Repository Layout

```text
Source/                  Theme implementation
Resources/               Theme bundle metadata and assets
Examples/ThemeDemo/      GNUstep-side demo app
Reference/AdwaitaDemo/   GTK4/libadwaita comparison harness
Reference/HeaderBar/     libadwaita header bar measurements and renders
Tests/Scripts/           Capture and local verification helpers
Docs/                    Public design notes and roadmap
```

## Requirements

Build requirements for the GNUstep theme bundle:

- GNUstep make and GNUstep GUI development environment
- `pkg-config`
- `gio-2.0`
- `glib-2.0`
- `gobject-2.0`

Reference app requirements:

- Python 3
- PyGObject
- GTK4
- libadwaita

## Build

```sh
make
make -C Examples/ThemeDemo
```

Install the theme for the current user:

```sh
make install GNUSTEP_INSTALLATION_DOMAIN=USER
```

The installed theme bundle will be placed under:

```text
~/GNUstep/Library/Themes/Adwaita.theme
```

## Run

Launch the GNUstep demo app with the Adwaita theme selected:

```sh
PATH=/usr/GNUstep/System/Tools:$PATH defaults write ThemeDemo GSTheme Adwaita
bash Tests/Scripts/run-theme-demo.sh
```

Launch the GTK reference app:

```sh
python3 Reference/AdwaitaDemo/adwaita_demo.py
```

Open a specific page in the reference app:

```sh
python3 Reference/AdwaitaDemo/adwaita_demo.py --page controls
python3 Reference/AdwaitaDemo/adwaita_demo.py --page data
python3 Reference/AdwaitaDemo/adwaita_demo.py --page text
```

## Settings

The theme reads these from the user's defaults for an app
(`defaults write APP KEY VALUE`, or `-KEY VALUE` on the command line), then
from the app's own Info.plist (`GnomeThemeMetrics`, `GnomeThemeMenuStyle`
and `GnomeThemeHeaderBarToolbar`, so an app can declare how it was
designed):

- `GnomeThemeMetrics`: `gnome` or `compact`. Apps whose windows are built in
  code get GNOME's metrics: the interface font at GNOME's size (11pt at
  96dpi, about 14.7px), bold button titles, libadwaita's button padding and
  tab height. Apps with a main Gorm or nib file (`NSMainNibFile`,
  `NSMainStoryboardFile` or `GSMainMarkupFile` in their Info.plist) get
  `compact` metrics instead: GNUstep's 12pt, regular-weight button titles,
  GNUstep's button margins and tab height, so layouts made at those metrics
  fit. Set it to override that choice.
- `GnomeThemeMenuStyle`: `menubar` (the default) or `primary`. With
  `primary` the menu bar becomes GNOME's main menu button (☰): at the end of
  the window's toolbar when it shows one, otherwise alone in a slim bar.
  Clicking it shows the app's menus, then its application menu's items
  (Preferences, About, Quit), as GNOME's primary menu lists them. The menu
  itself is unchanged, so key equivalents and validation work as before.
- `GnomeThemeHeaderBarToolbar`: `YES` puts the window's toolbar in the
  header bar's row, as a GNOME app packs its buttons there, instead of a
  row of its own (only with the header bar, below). Items before the
  toolbar's flexible space go at the bar's start, items after it at its
  end, and the title in the space; icons are shown without labels, and an
  item without an icon is a text button. Items that don't fit go into the
  toolbar's » menu; in right-to-left languages the bar is mirrored. Off by
  default: the toolbar has to suit it (a few icons, a flexible space).
- `GnomeFontScale`: a factor (0.8–2.0) applied to the interface font.

### Windows without the menu bar

GNOME apps keep their menus in the main window. The theme leaves the menu
bar (or ☰) out of a window titled "Preferences" or "Settings" (with or
without "…"), unless it is the app's only window that can become main. An
app decides for itself by giving the window a delegate that implements:

```objc
- (BOOL) windowShouldShowMenuBar: (NSWindow *)window;
```

Its answer wins over the title, both ways, so this also covers other
auxiliary windows and titles in other languages. Key equivalents still
work in a window without the menu bar: GNUstep sends them to the main menu.

### Header bar (in development)

With `GSX11HandlesWindowDecorations NO` (a user default, for example
`defaults write NSGlobalDomain GSX11HandlesWindowDecorations NO`), GNUstep
draws the window decorations instead of the window manager, and this theme
draws them as libadwaita's header bar: one 46pt row with the bold title
centred, round window buttons in the order of GNOME's `button-layout`, and
the primary menu's ☰ before them. Drag the bar to move the window; resize
from any edge or corner; double-click the bar for GNOME's
`action-double-click-titlebar` action (maximise by default); right-click it
for the window menu. On X11 (GNUstep apps on GNOME run under Xwayland) the
window manager does the moving, resizing and maximising, as for GTK's
windows: under Mutter that brings snapping, tiling, dragging past the
screen's edge, Super-drag and Mutter's own window menu. Without a window
manager that supports it, the header bar does these itself. It follows the
scale factor (`GSScaleFactor`), mirrors in right-to-left languages, and has
libadwaita's high contrast details. Alerts have no bar, as GNOME's. The
theme can't set the flag itself: GNUstep's backend reads it before any theme
loads.

With `GnomeThemeHeaderBarToolbar` (above) the window's toolbar goes in the
bar's row.

Not yet with the installed GNUstep: the shadow, rounded corners (of
windows, menus and tool tips) and resizing from the shadow. These need the
libs-back and libs-gui patches in `Docs/upstream-patches/` (see
`Docs/PROPOSAL_LIBS_BACK_CSD.md`); without them menus and tool tips are
square.

`make check-mutter` checks the header bar with Mutter as the window manager:
GNOME Shell on a private Xvfb display, with its own D-Bus session and no
gvfs (see `Tests/Scripts/run-mutter-check.sh`).

### Designing a GNOME-style app in Gorm

Gorm itself runs with compact metrics (its own windows come from Gorm files
laid out at GNUstep's). An app meant to look like a GNOME app needs its
windows laid out at GNOME's metrics instead:

1. Declare it in the app's Info.plist, so it runs with GNOME's metrics even
   though it has a main Gorm file (and, if you like, the primary menu):

   ```
   GnomeThemeMetrics = gnome;
   GnomeThemeMenuStyle = primary;
   ```

   With GNUstep Make, put these in `APPNAMEInfo.plist` next to the makefile.
2. Install the Adwaita palette: controls at GNOME's sizes (34pt buttons,
   entries, pop-ups and search fields, a suggested button, checkboxes,
   radios, heading and body labels). Gorm's own palettes make 22pt controls.

   ```sh
   make palette installpalette GNUSTEP_INSTALLATION_DOMAIN=USER
   defaults write Gorm UserPalettes \
     '("'$HOME'/GNUstep/Library/ApplicationSupport/Palettes/Adwaita.palette")'
   ```

   (or open it once with Palettes ▸ Open… in Gorm's Tools menu, which
   remembers it). It appears as the last icon in Gorm's palette panel.
3. Lay its windows out in Gorm running with GNOME's metrics, so what you see
   is what the app will show:

   ```sh
   openapp Gorm -GnomeThemeMetrics gnome
   ```

   Gorm's own inspectors are cramped at this size (some labels clip), but the
   document's windows show the app's real text and control sizes. Size push
   buttons and text fields 34pt high, and leave GNOME's spacing: 6pt between
   related controls, 12pt between groups, 18pt from the window's edge.
4. Leave control fonts at the system font's default size (Gorm's default,
   and the palette's). Those are archived as "the system font" and follow
   the metrics the app runs with; a font given an explicit size keeps it.

## Development Notes

The fastest practical review loop is:

```sh
make
make -C Examples/ThemeDemo
bash Tests/Scripts/run-theme-demo.sh --page controls
make check-quirks
```

The demo and capture scripts load the theme bundle built in this checkout
(`Adwaita.theme`, by absolute path), not the installed copy: `-GSTheme Adwaita`
finds `~/GNUstep/Library/Themes/Adwaita.theme`, which may be older. Pass
`--theme PATH` (or set `ADWAITA_THEME`) to check another build. Install for
other apps with `make install GNUSTEP_INSTALLATION_DOMAIN=USER`.

`make check-quirks` runs `Tests/Scripts/run-quirk-probe.sh`: it builds
`Examples/QuirkProbe` and runs it on a private Xvfb display against the built
theme. The probe renders controls offscreen and measures them (sized button and
checkbox titles, wrapping labels and alert text, toolbar image items, the bold
font, the menu bar in a window created after launch, table grid lines,
frames and headers, the menu bar's app item, toolbar edges and hover,
pop-up titles, and the size of hidden tool tip and drag windows), prints one
PASS/FAIL/KNOWN/SKIP line per check, and exits with the number of failures.
KNOWN marks a GNUstep bug the theme can't fix (see `Docs/upstream-issues/`).
Add `--output DIR` to save a PNG of each probe window. `make check-quirks`
runs the probe six times: with the menu bar and with the primary menu
(`QUIRK_PROBE_ARGS="-GnomeThemeMenuStyle primary"`), each with the window
manager's title bar and with the theme's header bar
(`-GSX11HandlesWindowDecorations NO`), then the header bar's checks alone in
the dark and high contrast palettes (`QUIRK_PROBE_STYLE=dark` or
`high-contrast` with `-ProbeOnly header-bar`). The probe sets the decoration
flag itself, so a user default doesn't change the runs.

Useful helpers:

- `bash Tests/Scripts/run-theme-demo.sh`
- `bash Tests/Scripts/run-quirk-probe.sh --output /tmp/quirk-probe`
- `bash Tests/Scripts/run-adwaita-demo.sh`
- `bash Tests/Scripts/capture-theme-demo.sh --page controls --output /tmp/theme-controls.png`
- `bash Tests/Scripts/capture-adwaita-demo.sh --page controls --output /tmp/adwaita-controls.png`
- `python3 Reference/AdwaitaDemo/adwaita_demo.py --dump-metrics`
- `python3 Tests/Scripts/import-adwaita-cursors.py`

`import-adwaita-cursors.py` imports the stock Adwaita diagonal resize Xcursor
assets from `/usr/share/icons/Adwaita/cursors` and writes GNUstep-loadable TIFF
resources into `Resources/ThemeImages`. These resources provide
`GSFrameResizeNWSECursor` and `GSFrameResizeNESWCursor` for Cocoa-style apps
that need frame/corner resize cursors before GNUstep exposes AppKit's
`NSCursor` frame-resize API directly.

ThemeDemo also accepts command automation for focused visual checks:

```sh
Examples/ThemeDemo/ThemeDemo.app/ThemeDemo --command-script /tmp/theme-demo.commands
Examples/ThemeDemo/ThemeDemo.app/ThemeDemo --command-fifo /tmp/theme-demo.fifo
python3 Reference/AdwaitaDemo/adwaita_demo.py --command-script /tmp/adwaita-demo.commands
python3 Reference/AdwaitaDemo/adwaita_demo.py --command-fifo /tmp/adwaita-demo.fifo
```

Supported commands are `page NAME`, `click X Y`, `focus NAME`, `blur-to NAME`,
`select-all`, `open-dropdown NAME`, `type TEXT`, `key TEXT`, `wait SECONDS`,
`display`, `screenshot PATH`, `screenshot-screen PATH`,
`capture-dropdown NAME PATH`, `capture-alert PATH`, and `quit`. Text audit names
are `primary`, `password`, `search`, `disabled`, `body`, and `combo`.
Coordinates are backing-pixel positions from the top-left of the internally
captured content image, so they line up with screenshots produced by
`screenshot PATH`. Use `screenshot-screen PATH` when auditing popups or dropdowns
that render outside the application content view; it uses GNUstep screen capture
first and falls back to `gnome-screenshot` only if needed. Use
`capture-dropdown NAME PATH` for GNUstep combo boxes whose popup tracking is
modal; it schedules the same internal screen capture while the popup is open.
Use `capture-alert PATH` to audit a stock document-close `NSAlert`.

## Internal Notes

If local-only working notes are needed, keep them under `.internal/`.

That directory is ignored on purpose so internal handoff notes, private paths,
and local debug artifacts do not show up in a public GitHub repository.

## License

This project is licensed under the GNU Lesser General Public License, either
version 2 of the License, or (at your option) any later version.

See [COPYING.LIB](./COPYING.LIB).

## Current Ownership

- Author: Daniel Boyd
