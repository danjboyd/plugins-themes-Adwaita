**Repository:** GNOME/mutter (gitlab.gnome.org)

**Filed:** not yet. The cause comes from reading the source; it has not been
reproduced on the desktop yet (see "Before filing").

**Title:** Wayland: a modal dialog that gets its parent after it is mapped is never attached

### Affected version

- Mutter 48.7 (Debian 13, `48.7-0+deb13u1`), GNOME Shell 48.7, Nautilus
  48.3, xdg-desktop-portal-gnome 48.0, Wayland session. The same code is in
  49.0, 50.0 and `main` (checked 2026-10-06).

### Bug summary

With `attach-modal-dialogs` on, a Wayland modal dialog is attached to its
parent only if it has the parent when Mutter creates its window. If the
parent comes later, the dialog stays an ordinary window: it moves on its
own, the parent doesn't move with it, and the parent isn't dimmed.

This is always the case for the file chooser portal with an X11 parent
(`parent_window` = `x11:<xid>`, as every Xwayland app passes): Nautilus's
`external_window_wayland_set_parent_of()` waits until the chooser is
mapped, because `mutter_x11_interop.set_x11_parent` needs a `MetaWindow`, and
only then sets the parent. So a native GTK app's file chooser is attached,
while an Xwayland app's opens over its window but isn't.

### Steps to reproduce

`late_transient_attach.py` (GTK 4, about 30 lines): a modal dialog whose
parent is set 1 second after it is mapped.

1. On a GNOME Wayland session, `python3 late_transient_attach.py --early`:
   the dialog is attached.
2. `python3 late_transient_attach.py`: the dialog is not attached.

Or with an Xwayland app: call `org.freedesktop.portal.FileChooser.OpenFile`
with `parent_window` `x11:<xid>` and `modal` true.

### What did you expect to happen

The dialog is attached once it has a parent, whenever the parent is set.

### Cause

`meta_window_set_transient_for()` (`src/core/window.c`) calls the class's
`set_transient_for` before it stores the new parent:

```c
  if (!klass->set_transient_for (window, parent))
    return;
  ...
  g_set_object (&window->transient_for, parent);
```

`meta_window_wayland_set_transient_for()` (`src/wayland/meta-window-wayland.c`)
recomputes `attached` there:

```c
  if (window->attached != meta_window_should_attach_to_parent (window))
    {
      window->attached = meta_window_should_attach_to_parent (window);
      meta_window_recalc_features (window);
    }
```

and `meta_window_should_attach_to_parent()` reads the parent through
`meta_window_get_transient_for (window)`, which still returns the old
parent (none). So setting a parent on a mapped dialog leaves `attached`
FALSE. Nothing else recomputes it for a Wayland window except a change to
the `attach-modal-dialogs` setting, so toggling the setting while the
dialog is open should attach it.

### Possible fix

Recompute `attached` after `window->transient_for` is set: move the
recomputation from `meta_window_wayland_set_transient_for()` into
`meta_window_set_transient_for()`, after `g_set_object()`, for Wayland
windows. It has to stay after the `window->attached && parent == NULL`
check, which closes an attached dialog whose parent goes away and relies on
`attached` still describing the old parent.

### Before filing

- Run `late_transient_attach.py` both ways on the desktop and note what
  each does (screenshots).
- With the theme's chooser open over a GNUstep app:
  `gsettings set org.gnome.mutter attach-modal-dialogs false` then `true`.
  If the chooser then attaches, the cause above is confirmed.
- Dan's sign-off on this text (`Docs/UPSTREAM_POLICY.md`).

Found for plugins-themes-Adwaita#44.
