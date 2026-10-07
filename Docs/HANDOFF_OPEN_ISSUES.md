# Handoff: the open issues (2026-10-07)

For picking up the theme's open work in a fresh session: where things
stand, the open issues on danjboyd/plugins-themes-Adwaita, how to build and
test, and the traps found so far. Each issue holds its own background and
code pointers; read it before starting.

## Where things stand

- **Released:** 0.1.0-alpha6 (tag `0.1.0-alpha6`, `506069c`), installed for
  Dan's user. Since alpha5: per-window metrics (#24), the menu bar's
  overflow menu (#25), text at the font's own size (#23), context menus at
  the pointer (#20), the first button no longer loading eight images
  (#50), tiling and window menu checks under four window managers (#14),
  the header bar documented as the default (#12), and the README's
  side-by-side screenshots (#49). Release steps: `.internal/RELEASING.md`
  (local only, not in git).
- **Header bar by default:** the theme's `GSThemeDomain` asks for it; it
  takes a libs-gui with the patch in `Docs/upstream-patches/libs-gui/`.
- **Upstream (#13):** libs-back patch 1 is libs-back#244 (no reply yet).
  Patch 2 has a review packet (`Docs/upstream-patches/review/libs-back-0002.md`,
  standalone `25affcd` on branch `x11-window-types`), waiting for Dan.
  The series in `~/git/gnustep/libs-back-series` is `dbfbe53`, `7ac2405`,
  `8589356`, `129aefc`, `9160d53` (2026-10-07). Packets for 3–5 and the
  libs-gui patch: in progress or in `review/`.
- **Upstream reports (#29):** drafts 2, 4 and 11 in `Docs/upstream-issues/`
  are ready for Dan's review; 12 and 13 are fixed on master (nothing to
  file); 10 is filed as GNOME/mutter#5106 (#44).
- **All suites pass** (2026-10-07): `make check-quirks` (7 configurations,
  0 failures), `check-file-chooser`, `check-mutter`, `check-nib-metrics`,
  `check-menu-timing`, `check-context-menu`, `check-scroller-drag`, and
  `check-wms` under GNOME Shell, KWin, Xfwm4 and Openbox.

## The open issues

| # | Issue | State |
|---|---|---|
| 13 | Send the libs-back and libs-gui patches upstream | Under way, one item at a time after Dan's sign-off (`Docs/UPSTREAM_POLICY.md`) |
| 29 | Report the remaining upstream issues | Drafts 2, 4, 11 ready for review |
| 23 | Text width against GTK | Now 1.4% narrower; matching exactly needs libs-gui to round text-derived sizes. Candidate to close |
| 26 | Gorm's inspectors cramped at GNOME's metrics | #24's per-window metrics could draw Gorm's design windows at GNOME's sizes; deferred until Dan has talked to Gorm's maintainer |
| 44 | File chooser not attached under Mutter | Waits on GNOME/mutter#5106 |
| 28 | Remove workarounds when upstream fixes land | A checklist; look again when GNUstep releases |

File upstream reports only when Dan says so, spaced out. Close an issue
from the commit that fixes it ("Fixes #n") once Dan has asked for the
push.

## Working with Dan

- He says when to commit, push and install ("commit it, push, and
  install"). Commit when a piece of work is done and tested; ask before
  pushing.
- Install: `make install GNUSTEP_INSTALLATION_DOMAIN=USER`, then check that
  the installed `Adwaita.theme/Adwaita` is identical to the build (`cmp`).
  Apps must be restarted to pick it up.
- Commit messages: a short subject ("Area: what changed"), a body saying
  why, and the Co-Authored-By line.
- **Anything sent to GNUstep follows `Docs/UPSTREAM_POLICY.md`**: tests or
  a reproducer, the GCC check (`Tests/Scripts/gcc-syntax-check.sh`),
  disclosure, and Dan's sign-off on the exact hash, recorded in
  `Docs/UPSTREAM_SIGNOFF.md` before it is sent. Dan may approve in the
  chat ("I approve libs-back-0001"); Claude then records it there, quoting
  him, and otherwise never writes in that file.
- Upstream text carries the disclosure line "Investigated, reproduced and
  written up with AI assistance (Claude)." Never write in Dan's voice that
  he checked something.

## Code conventions

- Overrides of GNUstep methods are named
  `_override<Class>Method_<selector>` in `GnomeTheme` categories, and call
  the original through `GnomeThemeOriginalMethod(_cmd, self, Class)` (not
  `-overriddenMethod:for:`, which only matches the exact class).
- Alignments: use `GnomeThemeCenterTextAlignment()` and
  `GnomeThemeRightTextAlignment()`, never `NSCenterTextAlignment` or
  `NSRightTextAlignment` directly. libs-gui master swapped their values,
  so a theme built against one release meant the other alignment on the
  other release. QuirkProbe checks should measure drawn ink, not
  `-alignment`, for the same reason.
- 0.32 versus master at run time: menu tracking is told apart by
  `-[NSImage isTemplate]`, alignments by `[NSParagraphStyle version] >= 4`.
- Window manager state goes through `Source/Adapters/GnomeThemeWindowManager.m`
  (Xlib via `GSDisplayServer`'s `-serverDevice`/`-windowDevice:`), e.g.
  `GnomeThemeWindowManagerHasAlpha()`, `...ShadowExtents()`,
  `...IsMaximized()`.
- Every fix gets a QuirkProbe check (`Examples/QuirkProbe/QuirkProbe.m`) or
  a `run-mutter-check.sh` check, and an entry in the Fixed table of
  `Docs/IMPROVEMENTS.md`. Remove the item from the open lists there.

## Building and testing

```
. /usr/GNUstep/System/Library/Makefiles/GNUstep.sh
make                      # the theme
make check-quirks         # QuirkProbe, 7 configurations, private Xvfb
make check-file-chooser   # open/save panels against a stand-in portal
make check-mutter         # GNOME Shell (X11) on a private Xvfb, stock libs
make check-mutter-shadow  # the same against the patched libs-gui/libs-back
make check-wms            # the header bar under GNOME Shell, KWin, Xfwm4, Openbox
```

- **Don't filter build output with `grep error`.** GNUstep's headers print
  hundreds of lines containing "error", and a real failure scrolls past.
  Grep for `^[^ ].*\.m:[0-9]+:[0-9]+: error` and `\*\*\*`, and check the
  product's timestamp.
- **QuirkProbe against libs-gui master:**
  `LD_LIBRARY_PATH=$HOME/git/gnustep/libs-gui-csd/Source/obj bash Tests/Scripts/run-quirk-probe.sh --no-build`.
  Checks that move the pointer only run on the probe's own Xvfb
  (`ProbeOwnsDisplay`).
- **Never drive the real desktop with xdotool.** Once it opened GNOME's
  overview mid-session. Use a private Xvfb, or post events inside the app.
- **No gvfs in test sessions.** The network is an iPhone, and a test
  session's gvfs mounts it. The scripts set `GIO_USE_VFS=local
  GVFS_DISABLE_FUSE=1 GIO_USE_VOLUME_MONITOR=unix`. Never delete across
  file systems (`rm -rf --one-file-system`).
- **Isolated defaults.** Dan has `GSX11HandlesWindowDecorations NO` set
  globally. Tests that need to start from nothing use a copy of
  `/etc/GNUstep/GNUstep.conf` with `GNUSTEP_USER_DEFAULTS_DIR` pointing at an
  empty directory (mode 0600), passed as `GNUSTEP_CONFIG_FILE`.
  `run-mutter-check.sh` does this itself.
- **Long sessions** (GNOME Shell for interactive checks) must run as
  background jobs. A `&` inside one shell call dies when that call ends.
- **Try ideas in a scratch app.** A 60-line AppKit program with a window
  and the control under test, driven by xdotool on a private Xvfb and
  logging to stderr, isolates a bug faster than ThemeDemo. ThemeDemo logs
  window resizes with `-ThemeDemoLogFrames YES`.

## The patched libraries

- **The upstream series (2026-10-06, updated 2026-10-07):** `~/git/gnustep/libs-back-series`
  (branch `ai-policy/csd-series`) and `~/git/gnustep/libs-gui-series`
  (branch `ai-policy/theme-backend-defaults`), git worktrees of the two
  repositories below, committed on current master. These are now what is
  proposed upstream, exported to `Docs/upstream-patches/libs-back/` and
  `libs-gui/` with `git format-patch`; see `Docs/upstream-patches/README.md`.
  The `-csd` worktrees below are what apps run with today and still hold
  the earlier draft (the libs-gui one without the registration-domain fix).
- **libs-back:** `~/git/gnustep/libs-back-csd`, branch csd-header-bar, base
  5db2ae7, all uncommitted. Build with `make` in the worktree.
- **libs-gui:** `~/git/gnustep/libs-gui-csd`, branch csd-theme-decorations,
  base ff49ac830 (libs-gui master), uncommitted. Build with
  `make ADDITIONAL_OBJCFLAGS=-Wno-error=format-security`.
- **Running an app against them:** `~/bin/gs-patched <app>` links the backend
  as `libgnustep-backcsd` and sets `LD_LIBRARY_PATH`.
- **After any patch change:** change the commit it belongs to in the
  series (with its ChangeLog entry and test), check that every commit
  still builds and passes on its own, re-export with
  `git format-patch -o Docs/upstream-patches/libs-back 9731f15` (the
  series' base; or `libs-gui`), and update `Docs/upstream-patches/README.md`.
  A patch sent on its own is a branch on current master (as
  `x11-window-types` for patch 2), exported to `libs-back-standalone/`.
- **libs-back's own tests load the installed backend** unless the config
  points elsewhere. Make a GNUstep.conf copy whose
  `GNUSTEP_USER_DIR_LIBRARY` is a directory holding
  `Bundles/libgnustep-back-032.bundle` (a symlink to the bundle under
  test) and whose `GNUSTEP_USER_DEFAULTS_DIR` is empty. `chmod 600` it:
  libs-base silently ignores a config file others can write, and the
  tests then load the installed backend (check with `LD_DEBUG=files`). Then run, on a
  private Xvfb:
  `GNUSTEP_CONFIG_FILE=<that> gnustep-tests .` in `libs-back-csd/Tests`.
  `cairo/pdfps.m` aborts against the installed libs-gui snapshot: its
  font roles keep the backend's names unretained, fixed on gui master by
  8a092cfa7 (`Docs/upstream-issues/12-…`); against gui master it runs.
- **Comparing with a clean backend:** check out the commit before the one
  under test in the series worktree, build it, and run that commit's
  test: the counts that fail are in each commit message and in
  `Docs/upstream-patches/README.md`.

## Pointers

- `Docs/IMPROVEMENTS.md`: the Fixed table (what was done and how), the
  open lists (each now links its issue) and the upstream reports.
- `Docs/HANDOFF_HEADER_BAR.md`: the header bar's design, the decisions and
  phase 2b's details (shadow, settling, scale factor).
- `Docs/PROPOSAL_LIBS_BACK_CSD.md`: what the libs-back patch does, its
  tests and its limits.
- `Docs/upstream-issues/`: draft upstream reports with minimal programs.
