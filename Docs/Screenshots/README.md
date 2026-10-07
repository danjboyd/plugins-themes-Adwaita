# Screenshots

## `compare/`: GNUstep's theme and Adwaita

The README's side-by-side shots. Taken 2026-10-07 (MarkdownViewer and
ScreenshotTool retaken the same day with the primary menu) on a private Xvfb with
GNOME Shell 48.7 (X11) as the window manager, never on a real desktop, with
libs-gui and libs-back built with the patches in `Docs/upstream-patches/`, the
theme built from this repository (0.1.0-alpha5 plus `main`), light style,
Cantarell 11 and empty GNUstep user defaults, so nothing a user set reaches
either side. Each app ran once per theme, by `-GSTheme GNUstep` or
`-GSTheme <repo>/Adwaita.theme`.

The helpers are in `Tests/Scripts/readme-shots/`. With `W` a scratch
directory:

```sh
H=Tests/Scripts/readme-shots
$H/session.sh "$W" 140 &          # GNOME Shell on :140; wait for "ready"
$H/app.sh "$W" Adwaita <app> [file] &
$H/place.sh "$W" "<title>" Adwaita 1036 740
$H/shot.sh "$W" out.png
$H/stop.sh "$W"                   # also deletes $W
```

Close an app between the two themes. An app with an edited document waits
at its save prompt, so `stop.sh` kills whatever runs on the session's
display.

### MarkdownViewer

`danjboyd/ObjcMarkdown` built in `~/git/ObjcMarkdown`, with its libraries on
`LD_LIBRARY_PATH` (`ObjcMarkdown/obj` and the three `third_party/*/obj`
directories), opening that repository's `README.md` in Read mode. Placed at
1036x740 visible (its minimum width) with `place.sh "^README.md"`. The
Adwaita side runs with `-GnomeThemeMenuStyle primary`: the menus are in the
header bar's ☰ and there is no menu bar row.

### ScreenshotTool

`danjboyd/ScreenshotTool` built in `~/git/ScreenshotTool`, opening
`weekly-report.png` (in `Tests/Scripts/readme-shots/`, drawn for these shots)
copied to `/tmp/Pictures`, so the GNUstep title bar shows a short path. The
GNUstep side keeps the image's full size (1200 wide; the app won't shrink
it). The Adwaita side runs with `-GnomeThemeMenuStyle primary`, as
MarkdownViewer's, and is placed with `place.sh "weekly-report" Adwaita
1200 808`, the image's height plus the header bar (taller, and the app
centres the image with empty bands above and below). Then, with
`drag.sh`:

- the highlighter (the default tool), three passes over "Linux up 18%";
- the arrow tool, from the right of the chart's title to the Linux bar.

The points depend on each layout: take a screenshot first and read them
off it.

### Gorm

The installed Gorm 1.5.0, as it starts (document window, Controls palette,
Inspector). Then:

1. Document ▸ New Application (by clicking the menu: key equivalents go to
   whichever window has focus), and minimize Untitled-1 (its miniwindow is
   moved out of the crop).
2. Windows placed side by side: the new document at the top left, the
   menu being designed below it, My Window (560x380) in the middle, the
   Controls palette under it and the Inspector on the right. Under GNUstep's
   theme each window is placed 37px lower, below Mutter's title bar.
3. From the palette into My Window, at the same places in its content
   area: a Button, the two-field form and a Switch; then the button is
   clicked, so the Inspector shows its attributes.
4. Cropped to the windows: `shot.sh "$W" out.png 1600x860+0+35` for the
   GNUstep side; the Adwaita side was cut at 1360x810+32+68 without
   trimming.

Gorm's own windows run with compact metrics (#24), and its inspectors are
cramped at GNOME's fonts (#26): the shots show both as they are.

## `theme-*.png`

ThemeDemo's controls, text and data pages under Adwaita, taken 2026-10-07 in
the same session as `compare/`:

```sh
$H/app.sh "$W" Adwaita Examples/ThemeDemo/ThemeDemo.app/ThemeDemo --page controls &
$H/shot.sh "$W" theme-controls.png      # likewise --page text and --page data
```
