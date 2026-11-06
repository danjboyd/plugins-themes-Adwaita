**Repository:** gnustep/libs-gui

**Title:** NSPrintOperation: the didRunSelector gets (success, contextInfo) instead of Cocoa's (printOperation, success, contextInfo)

### Summary

`-runOperationModalForWindow:delegate:didRunSelector:contextInfo:` calls
the delegate's selector with two arguments, `success` and `contextInfo`.
Cocoa's selector takes three:

```objc
- (void) printOperationDidRun: (NSPrintOperation *)printOperation
                      success: (BOOL)success
                  contextInfo: (void *)contextInfo;
```

So a delegate written for Cocoa's signature gets `success` where the
operation should be, `contextInfo` where `success` should be, and an
undefined value for `contextInfo`. It can't tell which operation finished,
and the context it passed doesn't come back.

### Steps to reproduce

Excerpt below; the complete program is `print_did_run.m`, to paste in or
attach. It runs an operation with
`-runOperationModalForWindow:delegate:didRunSelector:contextInfo:` and
prints the three arguments its delegate got. Its print panel is a
stand-in whose sheet ends at once with `NSCancelButton`, calling the
didEndSelector as `-[NSApplication beginSheet:...]` does, so nothing is
printed.

```objc
- (void) printOperationDidRun: (NSPrintOperation *)printOperation
                      success: (BOOL)success
                  contextInfo: (void *)contextInfo
{
  printf ("printOperation: %p (the operation is %p)\n", ...);
  printf ("success:        %d (want 0, the sheet was cancelled)\n", ...);
  printf ("contextInfo:    %p (passed %p)\n", ...);
}

/* main(): */
theOperation = [NSPrintOperation printOperationWithView: view];
[theOperation setPrintPanel: panel];   /* the stand-in */
[theOperation runOperationModalForWindow: window
                                delegate: delegate
                          didRunSelector: @selector(printOperationDidRun:success:contextInfo:)
                             contextInfo: &expectedContext];
```

`./print_did_run -GSTheme GNUstep -GSPrinting GSLPR` on libs-gui master
8ac9f1db1:

```
printOperation: (nil) (the operation is 0x55f95a8decc8)  FAIL
success:        919159232 (want 0, the sheet was cancelled)  FAIL
contextInfo:    0x7f9afcff3530 (passed 0x55f936c941c0)  FAIL
```

The operation argument is `success` (NO, so nil); the other two are not
what was passed. Three runs on master and three on the installed 0.32.0 gui all give
the same three FAILs, with other `success` and `contextInfo` values.

### Expected

The delegate gets the operation, whether it succeeded, and the
`contextInfo` it passed, as in Cocoa.

### Cause

Source/NSPrintOperation.m, `-_printOperationDidRun:returnCode:contextInfo:`
(lines 702-727 on master), the print panel's didEndSelector:

```objc
  void (*didRun)(id, SEL, BOOL, id);
  ...
  if (delegate != nil && didRunSelector != NULL)
    {
      didRun = (void (*)(id, SEL, BOOL, id))[delegate methodForSelector:
                                                          didRunSelector];
      didRun (delegate, didRunSelector, success, contextInfo);
    }
```

GNUstep's own caller is written for this two-argument form:
`-[NSDocument runModalPrintOperation:delegate:didRunSelector:contextInfo:]`
(Source/NSDocument.m, lines 1484-1495) passes
`@selector(_runModalPrintOperationDidSucceed:contextInfo:)`, declared at
line 1497 as `- (void) _runModalPrintOperationDidSucceed: (BOOL)success
contextInfo: (void *)context`.

### Suggested fix

In `-_printOperationDidRun:returnCode:contextInfo:`, call the selector
with the operation first:

```objc
  void (*didRun)(id, SEL, NSPrintOperation *, BOOL, void *);
  ...
      didRun = (void (*)(id, SEL, NSPrintOperation *, BOOL, void *))
        [delegate methodForSelector: didRunSelector];
      didRun (delegate, didRunSelector, self, success, contextInfo);
```

and change NSDocument's `_runModalPrintOperationDidSucceed:contextInfo:`
to the three-argument form (`_printOperation:didRun:contextInfo:` or
similar) in the same change, or document printing breaks.

Related, from reading the code only (not reproduced here):
`-[NSDocument runModalPageLayoutWithPrintInfo:delegate:didRunSelector:contextInfo:]`
(lines 1405-1421) passes the caller's didRunSelector straight to
`-[NSPageLayout beginSheetWithPrintInfo:...didEndSelector:...]`, and
`-[NSApplication beginSheet:...]` calls it as `(sheet, returnCode,
contextInfo)` (Source/NSApplication.m, lines 2099-2105). A delegate with
Cocoa's `-document:didRunPageLayout:contextInfo:` then gets the page
layout panel where the document should be.

### Workaround

A delegate that must work with GNUstep can implement the two-argument
form (`- (void) printOperationDidRun: (BOOL)success contextInfo: (void
*)contextInfo`), or keep the operation in an instance variable instead of
relying on the callback's first argument.

### Environment

- Reproduced 2026-11-06 with libs-gui master 8ac9f1db1 (unpatched, run
  uninstalled through `LD_LIBRARY_PATH`, confirmed with `ldd`) and with
  the installed 0.32.0 gui (a Debian build of the master snapshot
  7892137bd carrying six local patches); libs-base 1.31.1;
  libs-back's GSLPR printing bundle (`-GSPrinting GSLPR`), nothing
  printed. First reproduced 2026-10-08 on master 549f639.
- Debian 13, clang 19, libobjc2 2.3 (gnustep-2.2 runtime), cairo/xlib
  backend, under Xvfb with no window manager.
- No existing issue or pull request found (searched "didRunSelector",
  "printOperationDidRun", "runOperationModalForWindow", "print
  contextInfo", 2026-11-06); NSPrintOperation.m's last change on master
  is 4eac748b6 (2011).

---

Investigated, reproduced and written up with AI assistance (Claude).
