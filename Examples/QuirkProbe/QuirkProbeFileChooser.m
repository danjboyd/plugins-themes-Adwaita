/*
   Copyright (C) 2026 Daniel Boyd

   This file is part of the GNUstep Adwaita theme.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/>.
*/

/* -ProbeOnly file-chooser: the open and save panels as GNOME's file
   chooser (plugins-themes-Adwaita#40), against the stand-in portal of
   Tests/Scripts/fake-file-chooser-portal.py, which logs each request to
   -ProbeFileChooserLog and answers with files in -ProbeFileChooserDir.
   With -ProbeFileChooserNoPortal YES there is no portal, and the panels
   must be GNUstep's. Run by Tests/Scripts/run-file-chooser-check.sh. */

#import "QuirkProbe.h"

@interface QuirkProbe (FileChooserResults)
- (void) pass: (NSString *)ident detail: (NSString *)detail;
- (void) fail: (NSString *)ident detail: (NSString *)detail;
- (void) finish;
@end

@interface NSSavePanel (QuirkProbeFileChooser)
- (BOOL) gnomeThemeUsesFileChooser;
@end

/* Counts the keys that reach it. */
@interface QuirkProbeKeyCounter : NSView
{
@public
  NSUInteger keys;
}
@end

@implementation QuirkProbeKeyCounter
- (BOOL) acceptsFirstResponder
{
  return YES;
}

- (void) keyDown: (NSEvent *)event
{
  keys++;
}
@end

/* NSDocument's "File Type" accessory, as -_createPanelAccessory builds it. */
@interface QuirkProbeSaveTypeTarget : NSObject
@end

@implementation QuirkProbeSaveTypeTarget
- (void) changeSaveType: (id)sender
{
}
@end

/* A delegate that filters names. */
@interface QuirkProbeFilteringDelegate : NSObject
@end

@implementation QuirkProbeFilteringDelegate
- (BOOL) panel: (id)sender shouldShowFilename: (NSString *)filename
{
  return YES;
}
@end

@implementation QuirkProbe (FileChooser)

- (void) check: (NSString *)ident that: (BOOL)ok detail: (NSString *)detail
{
  if (ok)
    {
      [self pass: ident detail: nil];
    }
  else
    {
      [self fail: ident detail: detail];
    }
}

/* The portal's requests so far. */
- (NSArray *) fileChooserRequests
{
  NSString *path = [[NSUserDefaults standardUserDefaults] stringForKey: @"ProbeFileChooserLog"];
  NSString *log = [NSString stringWithContentsOfFile: path];
  NSMutableArray *requests = [NSMutableArray array];
  NSEnumerator *e = [[log componentsSeparatedByString: @"\n"] objectEnumerator];
  NSString *line;

  while ((line = [e nextObject]) != nil)
    {
      id request;

      if ([line length] == 0)
        {
          continue;
        }
      request = [NSJSONSerialization JSONObjectWithData: [line dataUsingEncoding: NSUTF8StringEncoding]
                                                options: 0
                                                  error: NULL];
      if (request != nil)
        {
          [requests addObject: request];
        }
    }
  return requests;
}

- (NSDictionary *) lastFileChooserRequest
{
  return [[self fileChooserRequests] lastObject];
}

- (void) postKeyTo: (NSTimer *)timer
{
  NSWindow *window = [timer userInfo];

  [NSApp postEvent: [NSEvent keyEventWithType: NSKeyDown
                                     location: NSMakePoint (10, 10)
                                modifierFlags: 0
                                    timestamp: 0
                                 windowNumber: [window windowNumber]
                                      context: nil
                                   characters: @"x"
                  charactersIgnoringModifiers: @"x"
                                    isARepeat: NO
                                      keyCode: 53]
           atStart: NO];
}

- (void) cancelPanel: (NSTimer *)timer
{
  NSSavePanel *panel = [timer userInfo];

  printf ("# GNUstep panel visible: %s\n", [panel isVisible] ? "yes" : "no");
  fflush (stdout);
  if ([panel isVisible])
    {
      [panel cancel: nil];
    }
  else
    {
      [NSApp abortModal];
    }
}

/* GNUstep's panels, when there is no portal. */
- (void) checkFileChooserWithoutPortal
{
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  NSTimer *timer = [NSTimer timerWithTimeInterval: 1.0
                                           target: self
                                         selector: @selector(cancelPanel:)
                                         userInfo: panel
                                          repeats: NO];
  NSDate *start = [NSDate date];
  NSInteger result;

  [[NSRunLoop currentRunLoop] addTimer: timer forMode: NSModalPanelRunLoopMode];
  result = [panel runModal];
  [self check: @"file-chooser-no-portal"
         that: (result == NSFileHandlingPanelCancelButton && [[NSDate date] timeIntervalSinceDate: start] > 0.5)
       detail: [NSString stringWithFormat: @"result %ld after %.2fs; expected GNUstep's panel, cancelled",
                         (long)result, [[NSDate date] timeIntervalSinceDate: start]]];
  [self finish];
}

- (void) checkFileChooser
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *dir = [defaults stringForKey: @"ProbeFileChooserDir"];
  NSWindow *parent = _controlsWindow;
  NSOpenPanel *open;
  NSSavePanel *save;
  NSDictionary *request;
  NSDictionary *options;
  NSArray *filters;
  NSString *expectedParent;
  NSInteger result;
  QuirkProbeKeyCounter *counter;

  if ([defaults boolForKey: @"ProbeFileChooserNoPortal"])
    {
      [self checkFileChooserWithoutPortal];
      return;
    }

  open = [NSOpenPanel openPanel];
  save = [NSSavePanel savePanel];
  [self check: @"file-chooser-classes"
         that: ([NSStringFromClass ([open class]) isEqualToString: @"GnomeThemeOpenPanel"]
                && [NSStringFromClass ([save class]) isEqualToString: @"GnomeThemeSavePanel"])
       detail: [NSString stringWithFormat: @"%@, %@", [open class], [save class]]];

  /* An open panel for two types, run for a window; keys sent to the app
     meanwhile go nowhere. */
  counter = AUTORELEASE ([[QuirkProbeKeyCounter alloc] initWithFrame: NSMakeRect (0, 0, 10, 10)]);
  [[parent contentView] addSubview: counter];
  [parent makeKeyAndOrderFront: nil];
  [parent makeFirstResponder: counter];
  [[NSRunLoop currentRunLoop] addTimer: [NSTimer timerWithTimeInterval: 0.05
                                                                target: self
                                                              selector: @selector(postKeyTo:)
                                                              userInfo: parent
                                                               repeats: NO]
                               forMode: NSModalPanelRunLoopMode];
  result = [open runModalForDirectory: dir
                                 file: nil
                                types: [NSArray arrayWithObjects: @"txt", @"md", nil]
                     relativeToWindow: parent];
  request = [self lastFileChooserRequest];
  options = [request objectForKey: @"options"];
  filters = [options objectForKey: @"filters"];
  expectedParent = [NSString stringWithFormat: @"x11:%lx", (unsigned long)[parent windowRef]];
  [self check: @"file-chooser-open"
         that: (result == NSFileHandlingPanelOKButton
                && [[[open URL] path] isEqualToString: [dir stringByAppendingPathComponent: @"a.txt"]]
                && [[open directory] isEqualToString: dir])
       detail: [NSString stringWithFormat: @"result %ld, URL %@, directory %@", (long)result, [open URL],
                         [open directory]]];
  [self check: @"file-chooser-open-request"
         that: ([[request objectForKey: @"method"] isEqualToString: @"OpenFile"]
                && [[request objectForKey: @"parent"] isEqualToString: expectedParent]
                && [[request objectForKey: @"title"] isEqualToString: @"Open"]
                && [[options objectForKey: @"modal"] boolValue]
                && [[options objectForKey: @"multiple"] boolValue] == NO
                && [[options objectForKey: @"directory"] boolValue] == NO
                && [[options objectForKey: @"current_folder"] isEqualToString: dir]
                && [options objectForKey: @"accept_label"] == nil)
       detail: [request description]];
  [self check: @"file-chooser-open-filters"
         that: ([filters count] == 3
                && [[[filters objectAtIndex: 0] objectAtIndex: 0] isEqualToString: @"All supported files"]
                && [[[[[filters objectAtIndex: 0] objectAtIndex: 1] objectAtIndex: 1] objectAtIndex: 1]
                     isEqualToString: @"*.[mM][dD]"]
                && [[options objectForKey: @"current_filter"] isEqual: [filters objectAtIndex: 0]])
       detail: [filters description]];
  [self check: @"file-chooser-modal-input"
         that: (counter->keys == 0)
       detail: [NSString stringWithFormat: @"%lu keys reached the window under the chooser",
                         (unsigned long)counter->keys]];
  [counter removeFromSuperview];

  /* Several files. */
  open = [NSOpenPanel openPanel];
  [open setAllowsMultipleSelection: YES];
  result = [open runModalForDirectory: dir file: nil types: nil];
  options = [[self lastFileChooserRequest] objectForKey: @"options"];
  [self check: @"file-chooser-open-multiple"
         that: (result == NSFileHandlingPanelOKButton && [[open URLs] count] == 2
                && [[options objectForKey: @"multiple"] boolValue] && [options objectForKey: @"filters"] == nil)
       detail: [NSString stringWithFormat: @"result %ld, URLs %@, options %@", (long)result, [open URLs], options]];

  /* A folder. */
  open = [NSOpenPanel openPanel];
  [open setCanChooseFiles: NO];
  [open setCanChooseDirectories: YES];
  [open setPrompt: @"Choose"];
  result = [open runModal];
  options = [[self lastFileChooserRequest] objectForKey: @"options"];
  [self check: @"file-chooser-open-folder"
         that: (result == NSFileHandlingPanelOKButton
                && [[open filename] isEqualToString: [dir stringByAppendingPathComponent: @"folder"]]
                && [[options objectForKey: @"directory"] boolValue]
                && [[options objectForKey: @"accept_label"] isEqualToString: @"Choose"])
       detail: [NSString stringWithFormat: @"result %ld, filename %@, options %@", (long)result, [open filename],
                         options]];

  /* Cancelled. */
  open = [NSOpenPanel openPanel];
  [open setTitle: @"Cancel me"];
  result = [open runModal];
  [self check: @"file-chooser-cancel"
         that: (result == NSFileHandlingPanelCancelButton)
       detail: [NSString stringWithFormat: @"result %ld", (long)result]];

  /* A save panel for one type; the name gets its extension. */
  save = [NSSavePanel savePanel];
  [save setAllowedFileTypes: [NSArray arrayWithObject: @"md"]];
  result = [save runModalForDirectory: dir file: @"notes"];
  request = [self lastFileChooserRequest];
  options = [request objectForKey: @"options"];
  [self check: @"file-chooser-save"
         that: (result == NSFileHandlingPanelOKButton
                && [[save filename] isEqualToString: [dir stringByAppendingPathComponent: @"notes.md"]]
                && [[request objectForKey: @"method"] isEqualToString: @"SaveFile"]
                && [[options objectForKey: @"current_name"] isEqualToString: @"notes.md"]
                && [[options objectForKey: @"filters"] count] == 1)
       detail: [NSString stringWithFormat: @"result %ld, filename %@, request %@", (long)result, [save filename],
                         request]];

  /* A sheet, with a completion handler, parented to its window. */
  {
    __block NSInteger sheetResult = -1;

    save = [NSSavePanel savePanel];
    [save setNameFieldStringValue: @"sheet.txt"];
    [save beginSheetModalForWindow: parent
                 completionHandler: ^(NSInteger r) { sheetResult = r; }];
    request = [self lastFileChooserRequest];
    [self check: @"file-chooser-sheet"
           that: (sheetResult == NSFileHandlingPanelOKButton
                  && [[request objectForKey: @"parent"] isEqualToString: expectedParent]
                  && [[[save URL] lastPathComponent] isEqualToString: @"sheet.txt"])
         detail: [NSString stringWithFormat: @"result %ld, URL %@, request %@", (long)sheetResult, [save URL],
                           request]];
  }

  /* Not blocking: the handler runs once the chooser answers. */
  {
    __block NSInteger asyncResult = -1;
    NSInteger before;
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow: 5];

    open = [NSOpenPanel openPanel];
    [open beginWithCompletionHandler: ^(NSInteger r) { asyncResult = r; }];
    before = asyncResult;
    while (asyncResult == -1 && [limit timeIntervalSinceNow] > 0)
      {
        [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
                                 beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.05]];
      }
    [self check: @"file-chooser-modeless"
           that: (before == -1 && asyncResult == NSFileHandlingPanelOKButton
                  && [[[open URL] lastPathComponent] isEqualToString: @"a.txt"])
         detail: [NSString stringWithFormat: @"before %ld, result %ld, URL %@", (long)before, (long)asyncResult,
                           [open URL]]];
  }

  /* When the panel stays GNUstep's. */
  {
    NSBox *box = AUTORELEASE ([[NSBox alloc] initWithFrame: NSMakeRect (0, 0, 380, 70)]);
    NSPopUpButton *popUp = AUTORELEASE ([[NSPopUpButton alloc] initWithFrame: NSMakeRect (115, 14, 150, 22)]);
    QuirkProbeSaveTypeTarget *target = AUTORELEASE ([QuirkProbeSaveTypeTarget new]);
    QuirkProbeFilteringDelegate *delegate = AUTORELEASE ([QuirkProbeFilteringDelegate new]);
    NSDictionary *argumentDomain = [defaults volatileDomainForName: NSArgumentDomain];
    NSMutableDictionary *off = [NSMutableDictionary dictionaryWithDictionary: argumentDomain];
    BOOL plain, document, custom, filtering, disabled;

    save = [NSSavePanel savePanel];
    plain = [save gnomeThemeUsesFileChooser];

    [popUp addItemWithTitle: @"Plain text"];
    [popUp setTarget: target];
    [popUp setAction: @selector(changeSaveType:)];
    [box addSubview: popUp];
    [save setAccessoryView: box];
    document = [save gnomeThemeUsesFileChooser];

    [save setAccessoryView: AUTORELEASE ([[NSButton alloc] initWithFrame: NSMakeRect (0, 0, 100, 24)])];
    custom = [save gnomeThemeUsesFileChooser];
    [save setAccessoryView: nil];

    [save setDelegate: delegate];
    filtering = [save gnomeThemeUsesFileChooser];
    [save setDelegate: nil];

    [off setObject: @"NO" forKey: @"GnomeThemeNativeFileDialogs"];
    [defaults removeVolatileDomainForName: NSArgumentDomain];
    [defaults setVolatileDomain: off forName: NSArgumentDomain];
    disabled = [save gnomeThemeUsesFileChooser];
    [defaults removeVolatileDomainForName: NSArgumentDomain];
    [defaults setVolatileDomain: argumentDomain forName: NSArgumentDomain];

    [self check: @"file-chooser-fallbacks"
           that: (plain && document && custom == NO && filtering == NO && disabled == NO)
         detail: [NSString stringWithFormat: @"plain %d, NSDocument accessory %d, other accessory %d, "
                           @"filtering delegate %d, GnomeThemeNativeFileDialogs NO %d",
                           plain, document, custom, filtering, disabled]];
  }

  [self finish];
}

@end
