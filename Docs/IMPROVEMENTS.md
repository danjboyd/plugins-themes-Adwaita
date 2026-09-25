# Improvement Backlog

A running list of theme bugs and GNOME-native polish, collected while building
OneDriveServiceManager with this theme (started 2026-09-24). Each item notes how
it was found. Compare against the libadwaita reference with
`python3 Reference/AdwaitaDemo/adwaita_demo.py --page PAGE --screenshot OUT.png`.

## Fixed

| Item | Fix |
| --- | --- |
| Image-only `NSToolbarItem`s drew nothing (image and label) | `GnomeThemeOriginalMethod()`: overrides reached from a subclass (`GSToolbarButtonCell`) found no original method |
| `sizeToFit` buttons clipped their last word ("Sign In" → "Sign") | `cellSize` measures with the drawing geometry (bezel margins + title insets) |
| `sizeToFit` checkboxes/radios clipped ("Errors only" → "Errors") | `cellSize` accounts for the ≥18pt indicator and 10pt gap |
| Multi-line labels and `NSAlert` informative text showed one line | `titleRectForBounds:` keeps the full rect for labels that need (and have room for) more lines |
| Password field text sat 10pt left of other fields' text | same subclass fix (`NSSecureTextFieldCell`) |
| ThemeDemo stuck at 2× after a `capture-theme-demo.sh --scale 2` run | the script passes `-GSScaleFactor`/`-GSTheme` as launch arguments |
| Bold text (`boldSystemFontOfSize:`, title bar, table headers) drew in DejaVu Sans Bold | the theme sets `NSBoldFont` to the interface font's bold face (`Cantarell_700wght`) |
| With `NSWindows95InterfaceStyle`, windows created after launch had no menu bar (GNUstep bug, upstream issue 2) | the theme attaches the main menu when a window that can become main, and has no menu, becomes key or main |
| Demo and capture scripts tested the installed theme (`-GSTheme Adwaita`), which was from Jul 27 | they pass the built bundle by absolute path (`--theme`/`ADWAITA_THEME` to override) and no longer save `GSTheme` in ThemeDemo's defaults |
| Table headers were bold, centred, on a grey band with separators | libadwaita style: small bold text in a dim colour (full colour for a clicked or sorted column), on the list's background, no separators; GNUstep's default centred titles start at the leading edge, lined up with the rows' text |
| Every table drew horizontal grid lines | grid lines only when the app asks (`setGridStyleMask:`/`setDrawsGrid:`, including tables decoded from a nib or Gorm file); GNUstep's own default of drawing a grid is treated as none, the GNOME and Cocoa default |
| Table scroll views had a bezel frame and lines between content and scrollers | no frame; the space is filled with the table's background, so the list reads as one plain area (other scroll views keep their frame) |
| Scrollers drew a grey track with a faint knob | overlay-style indicator: no track, a thin dim slider along the outer edge, thicker and darker while dragged; hidden when nothing overflows |
| A dark grey line under every toolbar | toolbars sit on the window background with a light bottom edge (the palette's `toolbarBackgroundColor`/`toolbarBorderColor`; GSTheme looked for them in a ThemeExtra colour list and fell back to dark grey) |
| Toolbar buttons had no hover or pressed look (pressed labels turned white) | libadwaita flat-button backgrounds: the text colour at 7% under the pointer, 16% pressed, 6pt corners; hover comes from tracking rects the theme adds in `-[GSToolbarButton layout]` |
| The menu bar started with the app's name, greyed when its menu was empty ("OneDriveServiceManager") | an empty app menu is removed; a non-empty one is drawn as GNOME's main-menu icon (☰) |
| `NSMenuItemCell` overrides used the exact-class lookup, and pop-up buttons' layout depended on it failing | they use `GnomeThemeOriginalMethod()`; pop-up button cells get their geometry explicitly, so an upstream fix to `-overriddenMethod:for:` can't move pop-up titles |

Regression checks for these live in `Examples/QuirkProbe`; run
`make check-quirks` (see the README).

## GNOME-native polish (suggested)

Seen side by side with the libadwaita reference (Data Views and Controls pages)
and in OneDriveServiceManager's main window.

1. **Row height and cell padding.** libadwaita rows are about 34px with 6px of
   text inset and wide column spacing; the theme's are about 28px with 3–4px.
   Density affects every app's layout, so change it deliberately.
2. **Icon-only toolbar items.** GNOME header bar buttons are icon-only with
   tooltips; GNUstep toolbars default to icon above label. The theme keeps the
   display mode the app sets; an app that wants the GNOME look can use
   `NSToolbarDisplayModeIconOnly` and set tooltips.
3. **Main menu at the end of the bar.** GNOME puts the main menu button at the
   right. The theme's ☰ stays first, because GSTheme moves the app item back to
   the front whenever it organises the menu.
4. **Alerts like `AdwAlertDialog`.** Centred bold heading and body, no app icon
   or separator line, equal-width buttons in a row (stacked when narrow), and
   rounded corners.
5. **Tab views.** GNOME uses flat tabs with an accent underline on the selected
   one (GtkNotebook) or a view switcher. The theme's pill tabs with a blue top
   bar read as custom.
6. **Checkbox and radio spacing.** GTK uses about a 6–8pt gap between indicator
   and label (theme: 10) and packs option groups tighter.

## Theme follow-ups

- **Scrollbars that hide until needed.** libadwaita shows its overlay
  indicators only after the pointer moves or the view scrolls, widens them
  under the pointer, and lets content run underneath. GNUstep's
  `NSTrackingArea` is declared but not wired into `NSView`, so hover needs
  legacy tracking rects kept up to date by hand, and content under the
  scrollers needs `-[NSScrollView tile]` changes. The indicator stays visible
  while content overflows, in a strip of its own.

- **Install after merging.** Apps load `~/GNUstep/Library/Themes/Adwaita.theme`.
  On 2026-09-24 that copy was from Jul 27, and all of OneDriveServiceManager's
  quirks (clipped titles, invisible toolbar items, one-line labels and alerts)
  came from it. Run `make install GNUSTEP_INSTALLATION_DOMAIN=USER` after each
  merge.
- **Remove workarounds when upstream fixes land.** The probe's
  `toolbar-view-item-image` check reports PASS instead of KNOWN once libs-gui
  stops clearing view images. Also drop `GnomeThemeOriginalMethod()`'s fallback
  when `-overriddenMethod:for:` walks superclasses, `-windowNeedsMainMenu:`
  when libs-gui attaches the menu to late windows, and the toolbar button
  tracking rects if libs-gui starts tracking for
  `showsBorderOnlyWhileMouseInside`.

## GNUstep issues to report upstream

Confirmed on 2026-09-24 with a minimal program under the default theme, both on
the installed gui 0.32.0 / base 1.31.1 and on master (gui ff49ac8, base
a8dd1b8). Draft issues and their programs are in `Docs/upstream-issues/`.

1. **libs-gui: a toolbar view item loses its view's image.** The cause is
   `-[NSToolbarItem _layout]`. It re-applies the item's own image, which is
   nil for a view item, and `GSToolbarBackView -setImage:` passes that nil to
   the view. The item isn't copied or archived. Workaround: also call
   `[item setImage:]` with the view's image.
2. **libs-gui: `NSWindows95InterfaceStyle` windows created after launch get
   no menu bar.** The menu reaches windows only through
   `-updateAllWindowsWithMenu:`, which runs when the main menu changes. Seen
   under GNOME/Mutter and under Xvfb. This theme works around it
   (`-[GnomeTheme windowNeedsMainMenu:]`); elsewhere, apps call
   `[window setMenu: [NSApp mainMenu]]`.
3. **libs-base: the main dispatch queue is drained only in
   `NSDefaultRunLoopMode`.** Main-queue blocks stall in the modal-panel and
   event-tracking modes, so they wait while a sheet, a modal panel or menu
   tracking is active (`NSRunLoop.m`, where the drainer is registered).
4. **libs-gui: `-[GSTheme overriddenMethod:for:]` matches only the receiver's
   exact class.** An override reached from a subclass gets 0 and can't call
   the original. This was the root cause of the invisible toolbar items; the
   theme works around it with `GnomeThemeOriginalMethod()`.

### Reported by OneDriveServiceManager: withdrawn

OneDriveServiceManager rechecked these on 2026-09-24 with the current theme
installed. None is a GNUstep bug; don't report them upstream.

- **A label holding one long "word" (a path) draws nothing.** Its text was
  four leading spaces and then the path. GNUstep wrapped at the spaces and
  put the path on a second line, which the one-line frame hid. Expected
  behaviour.
- **A pop-up button with the focus takes Return.** The window had no default
  button cell, only a button with a Return key equivalent.
  `setDefaultButtonCell:` fixes it, matching the probe.
- **Return/Esc key equivalents stop working after another panel closes.**
  Seen only with xdotool's synthetic events, sent to a window that had lost
  the focus. Not a proven bug. Calling `makeKeyAndOrderFront:` on the window
  again is still good UX.
- **The toolbar view-item image loss is not caused by copying or archiving**
  (OneDriveServiceManager's first guess). Upstream item 1 above gives the real
  cause. OneDriveServiceManager now uses plain image items, so it no longer
  needs the workaround.
