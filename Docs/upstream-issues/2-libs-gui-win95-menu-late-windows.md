**Repository:** gnustep/libs-gui

**Title:** NSWindows95InterfaceStyle: windows created after launch get no menu bar

### Summary

With `NSMenuInterfaceStyle = NSWindows95InterfaceStyle`, the main menu is
drawn inside each window. That only happens for windows that already exist
when the main menu is first updated. A window created later (a document
window, a detail window, a window opened from a menu command) has no menu
bar unless the app calls `[window setMenu: [NSApp mainMenu]]` itself.

### Steps to reproduce

Excerpt below; the complete program is `win95_late_window_menu.m`, to paste in or attach. Run it with
`-NSMenuInterfaceStyle NSWindows95InterfaceStyle`. It sets the main menu,
opens one window in `applicationDidFinishLaunching:` and a second window one
second later, then checks both.

```objc
- (void) applicationDidFinishLaunching: (NSNotification *)n
{
  early = [self windowAt: 100 title: @"Early"];
  [early makeKeyAndOrderFront: nil];
  /* openLate: creates a second window the same way and makes it key. */
  [NSTimer scheduledTimerWithTimeInterval: 1.0 target: self
                                 selector: @selector(openLate:) userInfo: nil repeats: NO];
  [NSTimer scheduledTimerWithTimeInterval: 2.0 target: self
                                 selector: @selector(check:) userInfo: nil repeats: NO];
}
```

Output:

```
window created at launch: menu attached
window created later:     menu none
```

On screen, the second window has no menu bar, even when it is the key and
main window. Same result under GNOME/Mutter and under Xvfb with no window
manager, and with the default theme.

### Expected

Every window that can become main shows the application menu, as on
Windows, without app code.

### Cause

The menu reaches windows only through `-[NSMenu update]`
(Source/NSMenu.m, line 1088 on master):

```objc
if (_menu.mainMenuChanged)
  {
    if (NSInterfaceStyleForKey(@"NSMenuInterfaceStyle", nil) == NSWindows95InterfaceStyle)
      {
        [[GSTheme theme] updateAllWindowsWithMenu: self];
      }
    _menu.mainMenuChanged = NO;
  }
```

`-updateAllWindowsWithMenu:` (Source/GSThemeMenu.m, line 163) walks
`[NSApp windows]` at that moment. `mainMenuChanged` is set only when the
menu changes (`-menuChanged`, line 536). Nothing attaches the menu to a
window that is created, or becomes main, afterwards.
`-[NSApplication _windowDidBecomeKey:]` calls `[_main_menu update]`, but the
flag is already clear by then.

### Suggested fix

When a window becomes key or main in this style and can become main, but its
menu isn't the main menu, call `[[GSTheme theme] updateMenu: [NSApp mainMenu]
forWindow: window]`. This could go in `-[NSApplication _windowDidBecomeMain:]`
or in `-[NSWindow becomeMainWindow]`.

### Workaround

`[window setMenu: [NSApp mainMenu]]` on every window the app creates after
launch.

### Environment

- libs-gui master ff49ac8 (2026-09-22), libs-base master a8dd1b8. Also seen
  with the released gui 0.32.0 and base 1.31.1.
- Debian 13, clang 19, libobjc2 (gnustep-2.2 runtime), cairo/xlib backend.
