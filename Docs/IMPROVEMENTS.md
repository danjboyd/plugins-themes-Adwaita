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

Regression checks for these live in `Examples/QuirkProbe`; run
`make check-quirks` (see the README).

## GNOME-native polish (suggested)

Seen side by side with the libadwaita reference (Data Views and Controls pages)
and in OneDriveServiceManager's main window.

1. **List and table headers.** libadwaita: small, dim, regular weight,
   left-aligned, no header border or column separators. Theme: bold, centred,
   framed, with vertical separators.
2. **No grid lines by default.** libadwaita column/list views have no row or
   column lines; the theme draws horizontal grid lines. Keep them only when the
   app asks for grid lines explicitly.
3. **No frame around table scroll views.** The reference shows the list as a
   plain view area; the theme adds a blue-grey frame.
4. **Overlay scrollbars.** GNOME scrollbars are thin and appear on hover or
   scroll; the theme shows a permanent horizontal scroller track even when
   nothing overflows.
5. **Menu bar app item.** With `NSWindows95InterfaceStyle`, the first item is
   the application name, drawn greyed ("OneDriveServiceManager"). GNOME apps have
   no app-name menu: hide that item, or fold the whole menu into a primary
   ("hamburger") menu button, as the GNOME HIG does.
6. **Toolbar as header bar.** GNOME uses flat, icon-only buttons with tooltips and
   hover highlight, on the window background, with no separator line. GNUstep's
   icon-above-label items look dated; the theme could draw items flat, with a
   hover state, and a lighter bottom edge.
7. **Alerts like `AdwAlertDialog`.** Centred bold heading and body, no app icon
   or separator line, equal-width buttons in a row (stacked when narrow), and
   rounded corners.
8. **Tab views.** GNOME uses flat tabs with an accent underline on the selected
   one (GtkNotebook) or a view switcher. The theme's pill tabs with a blue top
   bar read as custom.
9. **Checkbox and radio spacing.** GTK uses about a 6–8pt gap between indicator
   and label (theme: 10) and packs option groups tighter.

## Theme follow-ups

- **`NSMenuItemCell` overrides still use the exact-class lookup.** Their only
  subclass is `NSPopUpButtonCell`, whose layout (`GnomeThemePhase67…`) was tuned
  to the original method being unreachable. Switching them to
  `GnomeThemeOriginalMethod()` moved long pop-up titles about 50pt right (stress
  page). Revisit together with the pop-up layout.
- **Install after merging.** Apps load `~/GNUstep/Library/Themes/Adwaita.theme`.
  On 2026-09-24 that copy was from Jul 27, and all of OneDriveServiceManager's
  quirks (clipped titles, invisible toolbar items, one-line labels and alerts)
  came from it. Run `make install GNUSTEP_INSTALLATION_DOMAIN=USER` after each
  merge.
- **Remove workarounds when upstream fixes land.** The probe's
  `toolbar-view-item-image` check reports PASS instead of KNOWN once libs-gui
  stops clearing view images. Also drop `GnomeThemeOriginalMethod()`'s fallback
  when `-overriddenMethod:for:` walks superclasses, and `-windowNeedsMainMenu:`
  when libs-gui attaches the menu to late windows.

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
