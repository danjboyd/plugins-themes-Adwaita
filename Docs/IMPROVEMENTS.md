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
- A regression harness: the "quirk probe" used here (image-only toolbar item,
  sized buttons and checkboxes, wrapping and long-word labels, a multi-line alert)
  could live in `Examples/` and be captured with the ThemeDemo pages.

## GNUstep (libs-gui) issues worth reporting upstream

These also show under the default theme, or are framework behaviour the theme
can only work around.

1. `-[GSTheme overriddenMethod:for:]` matches only the receiver's exact class;
   it should walk up the superclasses. This is the root cause of the toolbar bug
   above; every theme is affected.
2. Toolbar item views are copied through archiving, so a button or image view
   whose image isn't backed by a file or name loses the image ("Butto" in
   the probe).
3. With `NSWindows95InterfaceStyle`, the menu bar only appears in a window after
   `[window setMenu:[NSApp mainMenu]]`.
4. `beginSheet:` runs a modal loop that doesn't drain the main dispatch queue,
   so work reporting through `dispatch_get_main_queue()` stalls or deadlocks
   while a sheet is up.
5. A focused pop-up button takes Return even when the window has a default button.
6. A label holding one long "word" (a path) draws nothing when it doesn't fit,
   instead of clipping or truncating it.
