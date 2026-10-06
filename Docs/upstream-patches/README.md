# Upstream patches

The libs-back and libs-gui changes the theme needs for window shadows,
rounded corners, popover shadows for menus, window types and turning
GNUstep-drawn decorations on from a theme (see
`Docs/PROPOSAL_LIBS_BACK_CSD.md` for the design). Prepared for
plugins-themes-Adwaita#13, to follow GNUstep's policy on AI-generated
content (`POLICY_AI.md` in gnustep/apps-gorm; posted to discuss-gnustep by
Gregory Casamento on 2026-03-12, reposted 2026-07-10, and kept in effect on
gnustep-dev on 2026-07-14).

**Nothing has been sent upstream.** Each patch waits on Dan's own review
(below). On the FSF copyright assignment, Dan decided on 2026-10-06 to
send without it, as GNUstep has already accepted his code, and to deal
with it if a maintainer raises it.

## The series

Made with `git format-patch`; apply with `git am`. Each commit has its own
ChangeLog entry and its own test, builds on its own, and its message says
what the test checks, why that is enough, what it guards against, how
many checks fail without the change, and what isn't covered.

**libs-back** (`libs-back/`), against master `9731f15`, branch
`ai-policy/csd-series` in `~/git/gnustep/libs-back-series`:

| # | Commit | Test | Without / with |
|---|---|---|---|
| 1 | Keep the window manager functions of windows the gui decorates (Motif hints; a bug fix) | `Tests/x11/motifhints.m` | 3 of 5 fail / 5 pass |
| 2 | Type menus, tool tips, drag images and modal panels as GTK does | `Tests/x11/windowtype.m` | 4 of 5 fail / 5 pass |
| 3 | An alpha channel for borderless windows, when a theme asks | `Tests/x11/borderlessalpha.m` | 1 of 4 fails / 4 pass |
| 4 | Window shadows and rounded corners for windows the gui decorates | `Tests/x11/shadowmargin.m`, `Tests/x11/shadowdrawing.m` | 12 of 17 fail, drawing can't run / 17 and 8 pass |
| 5 | Popover shadows for menus, when a theme asks | the same two tests, extended | the popover checks fail / 21 and 14 pass |

1 and 2 stand alone; 4 needs 3 (the 32-bit visual), and 5 needs 4.
Every commit was built and its `x11` tests run on their own (54, 59, 63,
88 and 98 passing, none failing). The whole libs-back suite: 335 passed,
none failed, at the end of the series, against 286 on master; the 49 more
are the new checks. `make check-mutter-shadow` (GNOME Shell 48.7 on a
private Xvfb) passes all 16 of its checks against the series.

**libs-gui** (`libs-gui/`), against master `549f63913`, branch
`ai-policy/theme-backend-defaults` in `~/git/gnustep/libs-gui-series`:

| # | Commit | Test | Without / with |
|---|---|---|---|
| 1 | Let a theme turn GNUstep-drawn window decorations on | `Tests/gui/GSTheme/backendDefaults.m` | doesn't run / 11 pass |

The whole libs-gui suite: 4800 passed against 4789 on master, and the
same 33 failed tests, 5 failed builds and 2 aborted files on both: they
are in master already, and the patch adds none.

## How the series meets the policy

| Policy | How |
|---|---|
| 4.2: all AI-assisted contributions must include tests | Every commit has a test in the package's own `gnustep-tests` framework, failing without the change (counts above, each run on a private Xvfb). |
| 4.2: what is tested, why the test is good enough, what failures it guards against | A "Testing:" paragraph in every commit message, plus what the tests don't cover. |
| 4.2: no Apple-specific conventions; the project also uses GCC | No literals, blocks, properties, dot syntax, ARC, fast enumeration or `@autoreleasepool` in any added line (checked by search). Every changed source and test file was run through GCC 14's Objective-C front end (`-fsyntax-only`) with no diagnostic in the file itself; the check was first shown to reject a planted array literal and block. GCC can't parse the installed clang/libobjc2 GNUstep headers fully, so this is a syntax check of our code, not a full GCC build. |
| 4.2 and 7: never open a PR before reviewing the code; be able to explain it | **Dan's to do** (below). The commit messages explain each change for that review. |
| 5: disclose AI assistance | An "AI assistance:" paragraph and a `Co-Authored-By: Claude` line in every commit. |
| 6: no material of unverifiable origin | All code written for these patches. The shadow numbers are measurements of libadwaita 1.7 windows under Mutter and libadwaita's published box-shadow values; no code was taken. Said in commits 4 and 5. |
| 6: no fabricated results | Every count in the commits and here comes from a run. |
| 7: reproduction steps, tests | `make check` steps below; each test's header comment says what display it needs. |
| Richard Frith-Macdonald on gnustep-dev (2026-04-13): one patch per issue, with its test and a ChangeLog entry | One commit per change, each with both. |

Changes made while preparing the series (beyond splitting it):

- **libs-back, found by GCC.** The shadow code called
  `-_checkWMSupports:` above its definition with no declaration. Clang
  accepts that silently; GCC assumes the method returns `id` and accepts
  any arguments, while it returns `BOOL`, so a GCC build could have read
  garbage from the return register. It is now declared with the other
  private methods (upstream did the same for `-_getExtents:`).
- **libs-back, found by running each commit on its own.**
  `borderlessalpha.m` made its "no compositing manager" window before the
  backend had processed the event saying the compositor had gone (the
  backend caches that from commit 4 on); it now lets the run loop turn
  first, as an application would.
- **libs-gui, a bug fix.** The draft tested the user's choice with
  `-objectForKey:`, which also sees the registration domain, so a value an
  application or library registered for `GSBackHandlesWindowDecorations`
  would have kept the theme's from being installed. It now looks only above
  the registration domain. The new test found it. The libs-gui that apps
  run with today (`~/git/gnustep/libs-gui-csd`, and the installed
  `+csd` package) still has the draft's version.
- **Tests set defaults for the test process only**, in the argument domain.
  The draft's `shadowmargin.m` used `-setBool:forKey:`, which would have
  written `GSBackHandlesWindowDecorations NO` and the shadow defaults into
  the defaults of whoever ran `make check`.
- **Tests flush the backend's connection before reading** what it set.
  Without that, "has no margin" checks could pass only because the
  property hadn't arrived yet.
- **New tests:** the Motif hints, the alpha channel and the shadow pixels
  had no test of their own; the drag image's window type had none either.
- The shadow template cache is a small struct instead of macros over
  parallel arrays.

## Before sending: Dan's part

Sending follows `Docs/UPSTREAM_POLICY.md`: Dan reviews each commit and signs
off on its hash in `Docs/UPSTREAM_SIGNOFF.md` before anything is sent.
GNUstep's policy puts these on the contributor, and they can't be done for
him:

1. **Review every patch** and be able to explain each change and why it is
   correct (policy 4.2 and 7). The commit messages are written to help.
2. ~~Settle the FSF copyright assignment question (#13).~~ Decided
   2026-10-06: send without it; deal with it if a maintainer asks.
3. **Send one pull request per commit**, libs-back in the order above
   (patch 1 and 2 can go first and alone).
4. Expect libobjc2's maintainer not to take AI-assisted changes; none of
   these touch libobjc2.

## Running the tests

Both packages' tests run with `gnustep-tests` from the package's `Tests`
directory. The x11 tests fork their own stand-in window manager and
compositing manager, so they need a display with neither: a private Xvfb.
Point a copy of `GNUstep.conf` at an empty defaults directory and, for
libs-back, at a user Library whose `Bundles/libgnustep-back-032.bundle`
links to the bundle under test.

- `x11/shadowdrawing.m` was run against libs-gui master. With libs-gui
  0.32 the process aborts in the gui before the first check
  (`-[GSCInlineString copy]` sent to a deallocated instance while the
  window is made), as `x11/windowtype.m`'s comment describes.
