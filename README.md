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

## Development Notes

The fastest practical review loop is:

```sh
make
make -C Examples/ThemeDemo
make install GNUSTEP_INSTALLATION_DOMAIN=USER
bash Tests/Scripts/run-theme-demo.sh --page controls
```

Useful helpers:

- `bash Tests/Scripts/run-theme-demo.sh`
- `bash Tests/Scripts/run-adwaita-demo.sh`
- `bash Tests/Scripts/capture-theme-demo.sh --page controls --output /tmp/theme-controls.png`
- `bash Tests/Scripts/capture-adwaita-demo.sh --page controls --output /tmp/adwaita-controls.png`
- `python3 Reference/AdwaitaDemo/adwaita_demo.py --dump-metrics`

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
