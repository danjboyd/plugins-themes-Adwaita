# Handoff: the open issues (2026-10-05)

Every open item in the theme now has a GitHub issue (#12–#29 on
danjboyd/plugins-themes-Adwaita). This document is for picking them up in a
fresh session: the issues, the order to take them in, how to build and
test, and the traps found so far. Each issue holds its own background and
code pointers; read it before starting.

## Where things stand

- `99dc18c` and `df659ea` (docs, tests and the exported libs-back patch
  for issues fixed on 2026-10-02) are pushed.
- #15 is done (2026-10-05) in the theme and the libs-back patch, not yet
  pushed or installed: the theme types windows as GTK does, and the patch
  (item 5 of `Docs/PROPOSAL_LIBS_BACK_CSD.md`) does most of it itself.
- Later on 2026-10-05, committed but not yet pushed or installed: #22
  (alerts attached to their window), #21 (translucent tool tips), #19
  (15px menus with libadwaita's popover shadow, a new part of the
  libs-back patch), #18 (high contrast as current GNOME) and #17 (overlay
  scrollbars).
- Also done on 2026-10-05 (pushed and installed): #33 (toolbar item
  views that act on the release, in the header bar), #31 (a document
  window's title is its file's name), #30 (the toolbar-in-the-bar setting
  for all apps, applied live) and #32 (template images tinted). #34 (a
  toolbar hide/show crash) reproduces with GNUstep's own theme too: not
  the theme's; see the issue. #14 has its first results (`make check-wms`).
- #40 (open and save panels as GNOME's file chooser, through the portal;
  replaces libs-OpenSave in the apps) committed and installed 2026-10-05,
  not pushed:
  `Source/Adapters/GnomeThemeFileChooser.m`, checked by
  `make check-file-chooser` (a stand-in portal on a private bus). Still to
  confirm on the desktop that Mutter attaches the chooser to its X11
  parent under Wayland, and to try an NSDocument app's Save As.
- The installed theme (`~/GNUstep/Library/Themes/Adwaita.theme`) matches
  `86fefbe`. Nothing in the theme binary has changed since.
- The header bar is done through phase 3 (`Docs/HANDOFF_HEADER_BAR.md`).
  The shadow and rounded corners need the patched libs-back (below).
- All suites pass: `make check-quirks` (7 configurations),
  `make check-mutter`, `make check-mutter-shadow` (14 checks), and the
  QuirkProbe run against libs-gui master.

## The issues

**Decided on 2026-10-05** (each issue has a comment saying so):

| # | Issue | Decision |
|---|---|---|
| 12 | Header bar as the default | Stays opt-in; revisit once #14 has been through the other window managers |
| 13 | Send the patches upstream | **Deferred** (still `needs-decision`). First ask gnustep-dev about AI-assisted contributions and whether the FSF assignment is still required |
| 14 | Other window managers | Approved and under way: KWin, Xfwm4, Openbox and picom are installed (picom's autostart is off for Dan's user); `make check-wms` |
| 16 | Pop-ups: open on the press or the release | Keep the press; closed |

**Theme work, ready to start** (label `enhancement`/`bug`), in the
suggested order:

| # | Issue | Size | Notes |
|---|---|---|---|
| 18 | High contrast as current GNOME does it | M | Settings + palette; clear target (libadwaita's HC stylesheet) |
| 21 | Tool tips translucent with a compositor | S | Alpha is already there; paint 80% black |
| 20 | Context menus just below the pointer | S | Measure GTK 4's offset first |
| 19 | Menus: 15px corners and a shadow | M | Corners are easy; the shadow needs the libs-back patch extended |
| 17 | Overlay scrollbars | L | The biggest visible gap; NSTrackingArea isn't wired, `-tile` changes |
| 22 | Alerts without a title bar | M | Easier with the header bar |
| 25 | Menu bars in narrow windows | M | Overflow menu |
| 24 | Compact metrics per window | M | Design question: how to tell nib windows apart |
| 27 | Gorm's CustomView palette item | S | Find Gorm's class first |
| 23 | Text 5% wider than GTK's | ? | Investigation; may be libs-back or fonts |

**Upstream** (label `upstream`): #26 (Gorm's inspectors, deferred until
Dan talks to Gorm's maintainer), #28 (workarounds to remove, a checklist),
#29 (drafts 2 and 4 to file, plus two new findings: libs-gui master's
`NSTextAlignment` renumbering and libs-back's flaky `pdfps.m`). File
upstream reports only when Dan says so, spaced out.

Close an issue from the commit that fixes it ("Fixes #n") once Dan has
asked for the push.

## Working with Dan

- He says when to commit, push and install ("commit it, push, and
  install"). Commit when a piece of work is done and tested; ask before
  pushing.
- Install: `make install GNUSTEP_INSTALLATION_DOMAIN=USER`, then check that
  the installed `Adwaita.theme/Adwaita` is identical to the build (`cmp`).
  Apps must be restarted to pick it up.
- Commit messages: a short subject ("Area: what changed"), a body saying
  why, and the Co-Authored-By line.
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

- **The upstream series (2026-10-06):** `~/git/gnustep/libs-back-series`
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
  `git format-patch -o Docs/upstream-patches/libs-back origin/master` (or
  `libs-gui`), and update `Docs/upstream-patches/README.md`.
- **libs-back's own tests load the installed backend** unless the config
  points elsewhere. Make a GNUstep.conf copy whose
  `GNUSTEP_USER_DIR_LIBRARY` is a directory holding
  `Bundles/libgnustep-back-032.bundle` (a symlink to the bundle under
  test) and whose `GNUSTEP_USER_DEFAULTS_DIR` is empty. Then run, on a
  private Xvfb:
  `GNUSTEP_CONFIG_FILE=<that> gnustep-tests .` in `libs-back-csd/Tests`.
  Expected: 307 passed, with `cairo/pdfps.m` sometimes aborting (it does on
  the clean backend too; #29).
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
