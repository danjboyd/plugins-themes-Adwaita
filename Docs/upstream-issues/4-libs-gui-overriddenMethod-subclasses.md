**Repository:** gnustep/libs-gui

**Title:** GSTheme -overriddenMethod:for: returns 0 when the receiver is a subclass of the overridden class

### Summary

A theme can override a method of another class with
`_override<Class>Method_<selector>`, and can call the original through
`[theme overriddenMethod: _cmd for: self]`. When the receiver is an
instance of a *subclass* of that class, and the subclass inherits the method,
the override runs, but `-overriddenMethod:for:` returns 0. So the override
can't call the original implementation.

This affects every theme that overrides a method of a class with subclasses.
For example, overriding `NSButtonCell` drawing also catches
`GSToolbarButtonCell`, `NSPopUpButtonCell` and app-defined button cells;
overriding `NSTextFieldCell` also catches `NSSecureTextFieldCell` and
`NSTableHeaderCell`. In those cases the original drawing is skipped: for
example, image-only toolbar items drew nothing.

### Steps to reproduce

Excerpt below; the complete program is `override_subclass.m`, to paste in or attach. A theme overrides `-[NSActionCell tag]` and calls
the original. `MyCell` subclasses `NSActionCell` without overriding `-tag`.

```objc
@implementation ReproTheme
- (NSInteger) _overrideNSActionCellMethod_tag
{
  typedef NSInteger (*TagIMP)(id, SEL);
  TagIMP original = (TagIMP)[[GSTheme theme] overriddenMethod: _cmd for: self];

  NSLog(@"  override called for %@: original IMP %p",
        NSStringFromClass([(id)self class]), original);
  return original ? original(self, _cmd) : -1;
}
@end

@interface MyCell : NSActionCell
@end
@implementation MyCell
@end

/* main(): */
[GSTheme setTheme: [[ReproTheme alloc] initWithBundle: nil]];
base = [NSActionCell new]; [base setTag: 7];
sub = [MyCell new];        [sub setTag: 7];
NSLog(@"NSActionCell tag = %ld", (long)[base tag]);
NSLog(@"MyCell tag       = %ld", (long)[sub tag]);
```

Output:

```
  override called for NSActionCell: original IMP 0x7fc6c0b749a0
NSActionCell tag = 7
  override called for MyCell: original IMP (null)
MyCell tag       = -1
```

### Expected

`-overriddenMethod:for:` returns the original IMP for any receiver that
reaches the override, including instances of subclasses.

### Cause

Source/GSTheme.m, line 1079 on master, matches the receiver's exact class:

```objc
Class cls = object_getClass(receiver);
...
if (m->cls == cls && sel_isEqual(selector, m->sel))
```

### Suggested fix

Walk up from `object_getClass(receiver)` through `class_getSuperclass()`, and
return the first entry whose `cls` matches that class and whose `sel`
matches. Stop at the first match, so a subclass with its own override still
gets its own original.

### Workaround (in theme code)

If the lookup returns 0, look it up again with a receiver of exactly the
overridden class, for example an instance created with
`class_createInstance(baseClass, 0)` and used only as a lookup key.

### Environment

- libs-gui master ff49ac8 (2026-09-22), libs-base master a8dd1b8. Also seen
  with the released gui 0.32.0.
- Debian 13, clang 19, libobjc2 (gnustep-2.2 runtime).
