# Design surfaces in Gorm (prototype, #26)

**Status:** a prototype, off unless you turn it on. It's theme code only,
with no changes to Gorm. Its purpose is to show Gorm's maintainer the idea.

## What it does

Gorm has a main Gorm file, so the theme gives Gorm compact metrics:
GNUstep's 12pt text, button margins and tab height. That is what Gorm's
own panels were laid out at.

With design surfaces on, the windows you design in get GNOME's metrics
instead, so a layout made there looks the way it will in an app with
GNOME's metrics. Gorm's design windows are `GormNSWindow` and
`GormNSPanel`. Gorm's own panels stay compact.

Turn it on for Gorm only:

```sh
defaults write Gorm GnomeThemeDesignSurfaces YES
```

or for one run:

```sh
Gorm -GnomeThemeDesignSurfaces YES
```

## Which metrics follow the window

| In a design window | With design surfaces on |
|---|---|
| Push button margins (rounded, round rect, textured rounded) and bold titles | GNOME's |
| Check box and radio indicator size | GNOME's |
| Tab view tab-row height | GNOME's |
| A button's `-cellSize` (what Gorm's size-to-fit uses) | GNOME's |
| Fonts | **unchanged:** each control keeps the font Gorm gave it |
| Table row height | **unchanged:** set when a table is made, before it is in a window, or decoded from the file |
| Menus, scrollers | **unchanged:** they are the app's, not a window's |

Elsewhere, nothing changes:

| Window | Metrics |
|---|---|
| Gorm's inspectors, palettes, document window and other panels | compact, as before |
| Test mode (Gorm runs copies of the design windows as ordinary windows) | compact |
| Any app other than Gorm | unaffected: the theme looks for Gorm's window classes by name, and no other app has them |

## What Gorm saves

Design surfaces change only what the theme reads while it draws and sizes
controls. The theme writes nothing into the objects you design, so it
adds nothing to the file. A size you choose yourself is saved, as always.
Size-to-fit should size a button by GNOME's margins, and the size it picks
is saved.

`make check-design-surfaces` checks both runs, on and off:

- **Metrics:** GNOME's in a stand-in `GormNSWindow`, compact in an ordinary
  window.
- **Fonts:** the same in both windows.
- **Archive:** a button's archive is byte-for-byte the same before and
  after it is sized and drawn in the design window.

Those checks use a stand-in window, not Gorm itself. The PR records the
run in real Gorm.

## Not done, on purpose

- **GNOME's font size in design windows.** A control's font is part of
  the file, so setting it would change what Gorm saves.
  `+[NSFont _fontWithName:size:role:]` could make a system font at
  GNOME's size that archives as the default size. That needs agreement
  with Gorm's maintainer first.
- **Palettes at GNOME's metrics.** Gorm's palettes are laid out compact.
  The theme's own palette (`Palettes/Adwaita`) has controls at GNOME's
  sizes.
- **Any change in Gorm.**
