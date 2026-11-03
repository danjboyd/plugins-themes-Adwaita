# Design note: a destructive-button API for libs-gui, and the Adwaita side

For gnustep (owner of the libs-gui carries), via gnustep-tools-lead. Lives in this repo so gnustep can fetch it. adwaita makes no libs-gui commits; this is the API and the theme half only. 2026-11-03.

## Why
GNOME marks a dangerous response (Delete, Discard, Remove) in red: AdwAlertDialog's DESTRUCTIVE appearance, or a `.destructive-action` button. Measured on GTK4 / libadwaita 1.7: the alert's "Delete" has text in `destructive_color`, #c30000 (light) or #ff938c (dark), on that colour at 15% over the dialog. libs-gui has no way for an app to say a button is destructive, so the Adwaita theme draws "Delete" as an ordinary, or the default blue, button (audit 2, mismatch #5).

## The API: Apple's, as it already exists
Apple added it in macOS 11 on NSButton, not NSAlert:

```objc
@interface NSButton
@property BOOL hasDestructiveAction;   // API_AVAILABLE(macos(11.0))
@end
```

An alert's buttons are NSButtons, so apps already write the portable code:

```objc
NSButton *delete = [alert addButtonWithTitle: @"Delete"];
if ([delete respondsToSelector: @selector(setHasDestructiveAction:)])
  [delete setHasDestructiveAction: YES];
```

So no NSAlert API is needed: the same code works on macOS and, with this change, on GNUstep.

## libs-gui changes (proposed)
1. **NSButton.h**, under `OS_API_VERSION(MAC_OS_VERSION_11_0, GS_API_LATEST)` as libs-gui marks newer API:
   `- (BOOL) hasDestructiveAction;` and `- (void) setHasDestructiveAction: (BOOL)flag;`
   They forward to NSButtonCell, as NSButton's other appearance properties do. NSButtonCell can carry the same pair as a GNUstep extension; the cell draws, so the theme reads it there.
2. **Storage, keeping the ABI:** NSButtonCell already uses NSCell's four `subclass_bool_*` bits. NSCell's `_cell` flags say "5 bits remain unused", so add `unsigned has_destructive_action: 1;` there. That stays in the same word, so the instance size and every subclass's layout are unchanged. An NSButtonCell ivar would change the layout for subclasses.
3. **Drawing hint:** after `setHasDestructiveAction:`, call `[[self controlView] setNeedsDisplay: YES]`.
4. **NSCoding:** encode the flag only when YES, under a GNUstep key (e.g. `GSHasDestructiveAction`), unless someone confirms the key Xcode writes for the property; don't guess Apple's name. Decoding defaults to NO, so existing nibs are unaffected.
5. **NSAlert: carry the flag into the panel.** GSAlertPanel doesn't show the buttons `-addButtonWithTitle:` returns. `setButton()` in NSAlert.m copies their title, key equivalent, modifier mask and tag onto the panel's own buttons, so the flag would be lost. Add one line there:
   `[control setHasDestructiveAction: [template hasDestructiveAction]];`
   It must also be reset to NO when a panel is reused for a template without it; the same assignment does that.
6. **GSTheme default:** nothing. GNUstep's theme ignores the flag, as AppKit before 11 did. It's purely a hint to themes.
7. **Tests:** a libs-gui test that the flag round-trips through NSButton, NSButtonCell and keyed archiving, and that `setButton()` copies it (NSAlert's panel button has it after `-addButtonWithTitle:` plus the setter).

## The Adwaita theme side (adwaita implements it once the API lands)
- **In an alert** (GSAlertPanel, the theme's AdwAlertDialog layout): a destructive button is AdwAlertDialog's DESTRUCTIVE response.
  - Text in `destructive_color`: red_3 #e01b24 (light) or red_4 #c01c28 (dark), with Oklab lightness clamped as for the accent (≤ 0.5 light, ≥ 0.85 dark; the theme's accent code (PR #112) already does this).
  - Fill: that colour at 15% over the dialog background.
  - Return's blue default fill goes to no button then, as in libadwaita, where the destructive response is the default but red.
- **Elsewhere** (a window's button): libadwaita's raised `.destructive-action`: fill `destructive_bg_color`, text `destructive_fg_color` (white), pressed and hover as the accent button's.
- **Detection:** `[cell respondsToSelector: @selector(hasDestructiveAction)] && [cell hasDestructiveAction]`, so the theme keeps working on a libs-gui without the API.
- **Probe:** a QuirkProbe check that alerts and buttons with the flag draw red (text and fill sampled against the colours above), skipped when libs-gui lacks the selector.

## Not proposed
No heuristic on titles ("Delete", "Remove"): wrong in other languages, and wrong for an app that means otherwise.
