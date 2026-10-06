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
