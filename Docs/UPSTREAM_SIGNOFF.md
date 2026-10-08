# Upstream sign-off

Dan's record that he has reviewed an item and that exact version may be
sent upstream (`Docs/UPSTREAM_POLICY.md`, stage 2).

A line is added by Dan, or by Claude recording an approval Dan gave in the
chat: explicit, naming the item, given after Claude presented that item's
review document and hash, quoted in Notes. Claude adds nothing else here,
and reads this table before sending anything: nothing is sent whose hash
isn't in it.

- A patch: the commit's hash (`git rev-parse` in the series worktree).
- An issue: `git hash-object` of the draft and of its reproducer.

Any change to an item after its line was added voids the line.

| Date | Item | Hash(es) reviewed | Notes | Sent |
|---|---|---|---|---|
| 2026-10-06 | libs-back 0001 | dbfbe5397bc18895ef3e49951574e312603b03fa | Approved in chat: "i approve libs-back-0001", after review document `Docs/upstream-patches/review/libs-back-0001.md` for this hash | [libs-back#244](https://github.com/gnustep/libs-back/pull/244), 2026-10-06 |
| 2026-10-06 | libs-back 0001 pull request text | b040cacb16bf32074607283075f34c47309c9057 (`Docs/upstream-patches/pr/libs-back-0001.md`) | Approved in chat: "I approve the libs-back-0001 PR text" | [libs-back#244](https://github.com/gnustep/libs-back/pull/244), 2026-10-06 |
| 2026-10-06 | Mutter issue: late transient not attached (#44) | 6118c612ab676472b23dc3718c40ce5e54273e3e (`Docs/upstream-issues/10-mutter-late-transient-not-attached.md`), f61459d74276f4d16f97ca565511cd91436eb3df (`late_transient_attach.py`) | Approved in chat: "I approve the Mutter late-transient report, use the browser", after the draft was presented with these hashes | [mutter#5106](https://gitlab.gnome.org/GNOME/mutter/-/issues/5106), 2026-10-06 |
| 2026-10-08 | libs-gui issue 2: NSWindows95InterfaceStyle, windows created after launch get no menu bar | 62c82f0544cb4f646bbea1478992a1c6e2500e4e (`Docs/upstream-issues/2-libs-gui-win95-menu-late-windows.md`), 8501413e20403f7471bab434fc0a7279d53dc39e (`win95_late_window_menu.m`) | Approved in chat: "I approve libs-gui issues 2, 4 and 11", after the review packet `Docs/upstream-issues/review/issues-2-4-11.md` presented these hashes | |
| 2026-10-08 | libs-gui issue 4: -overriddenMethod:for: returns 0 for a subclass of the overridden class | 50909aab032e4fb6643ba19f8a1ba48cb14c2cdb (`Docs/upstream-issues/4-libs-gui-overriddenMethod-subclasses.md`), 50511ece6fecb30a917acbbdeb952623820903f6 (`override_subclass.m`) | Approved in chat: "I approve libs-gui issues 2, 4 and 11", after the review packet `Docs/upstream-issues/review/issues-2-4-11.md` presented these hashes | |
| 2026-10-08 | libs-gui issue 11: NSScroller without arrows puts its knob one arrow down | 6c51be21a1140aa14c2eaaad4a0c0fe91a039fed (`Docs/upstream-issues/11-libs-gui-scroller-knob-without-arrows.md`), 94f62dfb5226ca7a4346cfbad6d8ab08344903b9 (`scroller_knob_offset.m`) | Approved in chat: "I approve libs-gui issues 2, 4 and 11", after the review packet `Docs/upstream-issues/review/issues-2-4-11.md` presented these hashes | |
