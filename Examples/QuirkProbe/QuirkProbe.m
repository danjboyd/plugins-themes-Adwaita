/*
   Copyright (C) 2025-2026 Daniel Boyd

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

#import "QuirkProbe.h"
#import <GNUstepGUI/GSTheme.h>
#include <stdio.h>
#include <stdlib.h>

static NSString *QuirkProbeImageItem = @"ImageItem";
static NSString *QuirkProbeViewItem = @"ViewItem";
static NSString *QuirkProbePath =
  @"/home/user/OneDrive/Documents/AVeryLongFolderNameWithoutAnySpaces/file.txt";

/* Seconds to let windows lay out and draw before measuring. */
static const NSTimeInterval QuirkProbeSettleDelay = 0.8;

/* Ink extent of the pixels a test accepts, in pixels. */
typedef struct
{
  NSInteger width;
  NSInteger height;
  NSUInteger count;
} QuirkProbeInk;

typedef BOOL (*QuirkProbePixelTest)(NSUInteger red, NSUInteger green, NSUInteger blue);

/* Dark text on a light control: well below the Adwaita borders and fills,
   and below the accent blue, which only focus rings use here. */
static BOOL
QuirkProbeIsTextInk (NSUInteger red, NSUInteger green, NSUInteger blue)
{
  return (red + green + blue) < 306;
}

/* The toolbar test image is magenta, a colour the theme never draws. */
static BOOL
QuirkProbeIsMagenta (NSUInteger red, NSUInteger green, NSUInteger blue)
{
  return red > 200 && green < 80 && blue > 200;
}

static NSBitmapImageRep *
QuirkProbeRender (NSView *view)
{
  NSRect bounds = [view bounds];
  NSBitmapImageRep *rep = [view bitmapImageRepForCachingDisplayInRect: bounds];

  [view cacheDisplayInRect: bounds toBitmapImageRep: rep];
  return rep;
}

static QuirkProbeInk
QuirkProbeMeasure (NSBitmapImageRep *rep, QuirkProbePixelTest test)
{
  QuirkProbeInk ink = { 0, 0, 0 };
  NSInteger samples = [rep samplesPerPixel];
  NSInteger bits = [rep bitsPerSample];
  NSUInteger maxValue = (bits >= 16) ? 65535 : ((1u << bits) - 1);
  BOOL hasAlpha = [rep hasAlpha];
  BOOL alphaFirst = ([rep bitmapFormat] & NSAlphaFirstBitmapFormat) != 0;
  NSInteger colorStart = (hasAlpha && alphaFirst) ? 1 : 0;
  NSInteger alphaIndex = hasAlpha ? (alphaFirst ? 0 : samples - 1) : -1;
  NSInteger minX = NSIntegerMax, minY = NSIntegerMax, maxX = -1, maxY = -1;
  NSUInteger pixel[5];
  NSInteger x, y;

  if (samples < 3 || samples > 5)
    {
      return ink;
    }
  for (y = 0; y < [rep pixelsHigh]; y++)
    {
      for (x = 0; x < [rep pixelsWide]; x++)
        {
          NSUInteger red, green, blue;

          [rep getPixel: pixel atX: x y: y];
          /* Skip transparent pixels: their colour samples are meaningless. */
          if (alphaIndex >= 0 && pixel[alphaIndex] * 2 < maxValue)
            {
              continue;
            }
          red = pixel[colorStart] * 255 / maxValue;
          green = pixel[colorStart + 1] * 255 / maxValue;
          blue = pixel[colorStart + 2] * 255 / maxValue;
          if (test (red, green, blue))
            {
              ink.count++;
              minX = MIN (minX, x);
              maxX = MAX (maxX, x);
              minY = MIN (minY, y);
              maxY = MAX (maxY, y);
            }
        }
    }
  if (ink.count > 0)
    {
      ink.width = maxX - minX + 1;
      ink.height = maxY - minY + 1;
    }
  return ink;
}

static QuirkProbeInk
QuirkProbeTextInk (NSView *view)
{
  return QuirkProbeMeasure (QuirkProbeRender (view), QuirkProbeIsTextInk);
}

static NSView *
QuirkProbeFindText (NSView *view, NSString *text)
{
  NSEnumerator *enumerator;
  NSView *subview;

  if ([view isKindOfClass: [NSTextField class]]
    && [[(NSTextField *)view stringValue] isEqualToString: text])
    {
      return view;
    }
  if ([view isKindOfClass: [NSTextView class]]
    && [[(NSTextView *)view string] isEqualToString: text])
    {
      return view;
    }
  enumerator = [[view subviews] objectEnumerator];
  while ((subview = [enumerator nextObject]) != nil)
    {
      NSView *found = QuirkProbeFindText (subview, text);

      if (found != nil)
        {
          return found;
        }
    }
  return nil;
}

@interface QuirkProbe ()
- (void) after: (NSTimeInterval)delay perform: (SEL)selector;
- (void) after: (NSTimeInterval)delay perform: (SEL)selector mode: (NSString *)mode;
- (void) pass: (NSString *)ident detail: (NSString *)detail;
- (void) fail: (NSString *)ident detail: (NSString *)detail;
- (void) known: (NSString *)ident detail: (NSString *)detail;
- (void) skip: (NSString *)ident detail: (NSString *)detail;
- (void) saveWindow: (NSWindow *)window named: (NSString *)name;
- (NSWindow *) windowWithFrame: (NSRect)frame title: (NSString *)title;
- (NSTextField *) labelWithText: (NSString *)text frame: (NSRect)frame;
- (NSImage *) magentaImage;
@end

@implementation QuirkProbe

- (id) init
{
  self = [super init];
  if (self != nil)
    {
      _windows = [NSMutableArray new];
      _sizedButtons = [NSMutableArray new];
      _alertText = RETAIN (@"The files stay on this computer and in OneDrive. "
        @"OneDriveServiceManager stops syncing this folder, removes its service, "
        @"and forgets its settings. You can add the library again later.");
    }
  return self;
}

- (void) dealloc
{
  RELEASE (_outputDirectory);
  RELEASE (_windows);
  RELEASE (_sizedButtons);
  RELEASE (_toolbarViewButton);
  RELEASE (_alertText);
  [super dealloc];
}

#pragma mark Results

- (void) report: (NSString *)status ident: (NSString *)ident detail: (NSString *)detail
{
  if ([detail length] > 0)
    {
      printf ("%-5s %s: %s\n", [status UTF8String], [ident UTF8String], [detail UTF8String]);
    }
  else
    {
      printf ("%-5s %s\n", [status UTF8String], [ident UTF8String]);
    }
  fflush (stdout);
}

- (void) pass: (NSString *)ident detail: (NSString *)detail
{
  _passed++;
  [self report: @"PASS" ident: ident detail: detail];
}

- (void) fail: (NSString *)ident detail: (NSString *)detail
{
  _failed++;
  [self report: @"FAIL" ident: ident detail: detail];
}

- (void) known: (NSString *)ident detail: (NSString *)detail
{
  _known++;
  [self report: @"KNOWN" ident: ident detail: detail];
}

- (void) skip: (NSString *)ident detail: (NSString *)detail
{
  _skipped++;
  [self report: @"SKIP" ident: ident detail: detail];
}

#pragma mark Helpers

/* A timer in one run loop mode. (A timer added to two modes can fire in
   both.) */
- (void) after: (NSTimeInterval)delay perform: (SEL)selector mode: (NSString *)mode
{
  NSTimer *timer = [NSTimer timerWithTimeInterval: delay
                                           target: self
                                         selector: selector
                                         userInfo: nil
                                          repeats: NO];

  [[NSRunLoop currentRunLoop] addTimer: timer forMode: mode];
}

- (void) after: (NSTimeInterval)delay perform: (SEL)selector
{
  [self after: delay perform: selector mode: NSDefaultRunLoopMode];
}

- (void) saveWindow: (NSWindow *)window named: (NSString *)name
{
  NSView *frameView = [[window contentView] superview];
  NSData *png;
  NSString *path;

  if (_outputDirectory == nil || frameView == nil)
    {
      return;
    }
  png = [QuirkProbeRender (frameView) representationUsingType: NSPNGFileType
                                                  properties: [NSDictionary dictionary]];
  path = [_outputDirectory stringByAppendingPathComponent:
    [name stringByAppendingPathExtension: @"png"]];
  [png writeToFile: path atomically: YES];
}

- (NSWindow *) windowWithFrame: (NSRect)frame title: (NSString *)title
{
  NSWindow *window = [[NSWindow alloc] initWithContentRect: frame
                                                 styleMask: NSTitledWindowMask
                                                   backing: NSBackingStoreBuffered
                                                     defer: NO];

  [window setTitle: title];
  [window setReleasedWhenClosed: NO];
  [_windows addObject: window];
  RELEASE (window);
  return window;
}

- (NSTextField *) labelWithText: (NSString *)text frame: (NSRect)frame
{
  NSTextField *label = [[NSTextField alloc] initWithFrame: frame];

  [label setStringValue: text];
  [label setBezeled: NO];
  [label setBordered: NO];
  [label setEditable: NO];
  [label setSelectable: NO];
  [label setDrawsBackground: YES];
  [label setBackgroundColor: [NSColor whiteColor]];
  return AUTORELEASE (label);
}

- (NSImage *) magentaImage
{
  NSImage *image = [[NSImage alloc] initWithSize: NSMakeSize (24, 24)];

  [image lockFocus];
  [[NSColor colorWithCalibratedRed: 1.0 green: 0.0 blue: 1.0 alpha: 1.0] set];
  NSRectFill (NSMakeRect (2, 2, 20, 20));
  [image unlockFocus];
  return AUTORELEASE (image);
}

#pragma mark Toolbar delegate

- (NSToolbarItem *) toolbar: (NSToolbar *)toolbar
      itemForItemIdentifier: (NSString *)identifier
  willBeInsertedIntoToolbar: (BOOL)flag
{
  NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier: identifier];

  [item setLabel: identifier];
  if ([identifier isEqualToString: QuirkProbeImageItem])
    {
      [item setImage: [self magentaImage]];
      /* Enabled, so the image draws at full colour. */
      [item setTarget: self];
      [item setAction: @selector(toolbarItemClicked:)];
    }
  else
    {
      NSButton *button = [[NSButton alloc] initWithFrame: NSMakeRect (0, 0, 36, 32)];

      [button setImage: [self magentaImage]];
      [button setImagePosition: NSImageOnly];
      [button setBordered: NO];
      [item setView: button];
      [item setMinSize: NSMakeSize (36, 32)];
      [item setMaxSize: NSMakeSize (36, 32)];
      ASSIGN (_toolbarViewButton, button);
      RELEASE (button);
    }
  return AUTORELEASE (item);
}

- (void) toolbarItemClicked: (id)sender
{
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *)toolbar
{
  return [NSArray arrayWithObjects: QuirkProbeImageItem, QuirkProbeViewItem, nil];
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *)toolbar
{
  return [self toolbarAllowedItemIdentifiers: toolbar];
}

#pragma mark Windows

- (void) addButtonTitled: (NSString *)title
                    type: (NSButtonType)type
                      at: (NSPoint)origin
                  inView: (NSView *)view
{
  NSButton *sized = [[NSButton alloc] initWithFrame: NSMakeRect (origin.x, origin.y, 10, 10)];
  NSButton *wide = [[NSButton alloc] initWithFrame: NSZeroRect];
  NSEnumerator *enumerator = [[NSArray arrayWithObjects: sized, wide, nil] objectEnumerator];
  NSButton *button;

  while ((button = [enumerator nextObject]) != nil)
    {
      [button setButtonType: type];
      if (type == NSMomentaryPushInButton)
        {
          [button setBezelStyle: NSRoundedBezelStyle];
        }
      [button setTitle: title];
    }
  [sized sizeToFit];
  /* The same button with room to spare: its title is the reference. The
     references get a column of their own, one per row: renders come from the
     window's backing store, so views must not overlap. */
  [wide setFrame: NSMakeRect (480, 420 - 45 * [_sizedButtons count],
                              NSWidth ([sized frame]) + 100, NSHeight ([sized frame]))];
  [view addSubview: sized];
  [view addSubview: wide];
  [_sizedButtons addObject: [NSArray arrayWithObjects: sized, wide, nil]];
  RELEASE (sized);
  RELEASE (wide);
}

- (void) buildWindows
{
  NSView *view;
  NSToolbar *toolbar;
  NSTextField *label;

  _controlsWindow = [self windowWithFrame: NSMakeRect (40, 40, 900, 470) title: @"QuirkProbe Controls"];
  view = [_controlsWindow contentView];

  [self addButtonTitled: @"Sign In" type: NSMomentaryPushInButton at: NSMakePoint (10, 410) inView: view];
  [self addButtonTitled: @"Resync Now" type: NSMomentaryPushInButton at: NSMakePoint (130, 410) inView: view];
  [self addButtonTitled: @"OK" type: NSMomentaryPushInButton at: NSMakePoint (290, 410) inView: view];
  [self addButtonTitled: @"Errors only" type: NSSwitchButton at: NSMakePoint (10, 370) inView: view];
  [self addButtonTitled: @"Start at login" type: NSSwitchButton at: NSMakePoint (150, 370) inView: view];
  [self addButtonTitled: @"Download everything" type: NSRadioButton at: NSMakePoint (10, 335) inView: view];

  _wrappingLabel = [self labelWithText: @"This note is long enough that it needs to wrap onto a second line in this label."
                                 frame: NSMakeRect (10, 220, 220, 80)];
  [view addSubview: _wrappingLabel];
  _newlineLabel = [self labelWithText: @"First line\nSecond line (explicit newline)"
                                frame: NSMakeRect (240, 220, 220, 80)];
  [view addSubview: _newlineLabel];
  /* One line of the labels' font, for comparing heights. */
  label = [self labelWithText: @"Thgy(" frame: NSMakeRect (10, 130, 100, 30)];
  [label setTag: 1];
  [view addSubview: label];

  _pathLabel = [self labelWithText: QuirkProbePath frame: NSMakeRect (10, 180, 220, 20)];
  [view addSubview: _pathLabel];
  _truncatedPathLabel = [self labelWithText: QuirkProbePath frame: NSMakeRect (240, 180, 220, 20)];
  [[_truncatedPathLabel cell] setLineBreakMode: NSLineBreakByTruncatingMiddle];
  [view addSubview: _truncatedPathLabel];

  [_controlsWindow makeKeyAndOrderFront: nil];

  _toolbarWindow = [self windowWithFrame: NSMakeRect (40, 560, 400, 120) title: @"QuirkProbe Toolbar"];
  toolbar = [[NSToolbar alloc] initWithIdentifier: @"QuirkProbe"];
  [toolbar setDelegate: self];
  [toolbar setDisplayMode: NSToolbarDisplayModeIconAndLabel];
  [_toolbarWindow setToolbar: toolbar];
  RELEASE (toolbar);
  [_toolbarWindow orderFront: nil];
}

#pragma mark Checks

- (void) checkSizedButtons
{
  NSEnumerator *enumerator = [_sizedButtons objectEnumerator];
  NSArray *pair;

  while ((pair = [enumerator nextObject]) != nil)
    {
      NSButton *sized = [pair objectAtIndex: 0];
      QuirkProbeInk sizedInk = QuirkProbeTextInk (sized);
      QuirkProbeInk wideInk = QuirkProbeTextInk ([pair objectAtIndex: 1]);
      NSString *ident = [NSString stringWithFormat: @"sizeToFit-title \"%@\"", [sized title]];
      NSString *detail = [NSString stringWithFormat: @"title ink %ldx%ld at %gpt wide, %ldx%ld with room to spare",
        (long)sizedInk.width, (long)sizedInk.height, NSWidth ([sized frame]),
        (long)wideInk.width, (long)wideInk.height];

      if (wideInk.count == 0)
        {
          [self fail: ident detail: @"reference button drew no title"];
        }
      else if (sizedInk.width + 1 >= wideInk.width
        && ABS (sizedInk.height - wideInk.height) <= 1)
        {
          [self pass: ident detail: detail];
        }
      else
        {
          [self fail: ident detail: [detail stringByAppendingString: @" (clipped or wrapped)"]];
        }
    }
}

- (void) checkLabel: (NSView *)label ident: (NSString *)ident lineHeight: (NSInteger)lineHeight
{
  QuirkProbeInk ink = QuirkProbeTextInk (label);
  NSString *detail = [NSString stringWithFormat: @"text ink %ldpt high, one line %ldpt",
    (long)ink.height, (long)lineHeight];

  if (lineHeight > 0 && ink.height * 2 >= lineHeight * 3)
    {
      [self pass: ident detail: detail];
    }
  else
    {
      [self fail: ident detail: [detail stringByAppendingString: @" (one line only)"]];
    }
}

- (NSInteger) lineHeight
{
  return QuirkProbeTextInk ([[_controlsWindow contentView] viewWithTag: 1]).height;
}

- (void) checkLabels
{
  NSInteger lineHeight = [self lineHeight];
  NSEnumerator *enumerator;
  NSTextField *label;

  [self checkLabel: _wrappingLabel ident: @"label-wraps" lineHeight: lineHeight];
  [self checkLabel: _newlineLabel ident: @"label-newline" lineHeight: lineHeight];

  enumerator = [[NSArray arrayWithObjects: _pathLabel, _truncatedPathLabel, nil] objectEnumerator];
  while ((label = [enumerator nextObject]) != nil)
    {
      QuirkProbeInk ink = QuirkProbeTextInk (label);
      NSString *ident = (label == _pathLabel) ? @"long-path-label" : @"long-path-label-truncated";
      NSString *detail = [NSString stringWithFormat: @"text ink %ldpt wide in a %gpt label",
        (long)ink.width, NSWidth ([label frame])];

      if (ink.width * 2 >= NSWidth ([label frame]))
        {
          [self pass: ident detail: detail];
        }
      else
        {
          [self fail: ident detail: [detail stringByAppendingString: @" (drew little or nothing)"]];
        }
    }
}

- (void) checkToolbar
{
  NSView *frameView = [[_toolbarWindow contentView] superview];
  QuirkProbeInk magenta = QuirkProbeMeasure (QuirkProbeRender (frameView), QuirkProbeIsMagenta);
  NSString *detail;

  /* Only the image-only item can draw magenta: the view item's image is lost
     (checked below). */
  detail = [NSString stringWithFormat: @"%lu image pixels drawn", (unsigned long)magenta.count];
  if (magenta.count >= 100)
    {
      [self pass: @"toolbar-image-item-draws" detail: detail];
    }
  else
    {
      [self fail: @"toolbar-image-item-draws" detail: detail];
    }

  if ([_toolbarViewButton image] == nil)
    {
      [self known: @"toolbar-view-item-image"
             detail: @"libs-gui: -[NSToolbarItem _layout] sets the view's image to nil "
                     @"(Docs/upstream-issues/1-libs-gui-toolbar-view-item-image.md)"];
    }
  else
    {
      [self pass: @"toolbar-view-item-image"
            detail: @"the view kept its image: fixed upstream? Update IMPROVEMENTS.md"];
    }
}

- (void) checkFonts
{
  NSFont *system = [NSFont systemFontOfSize: 0];
  NSFont *bold = [NSFont boldSystemFontOfSize: 0];
  NSString *detail = [NSString stringWithFormat: @"system %@, bold %@",
    [system fontName], [bold fontName]];

  if ([[system familyName] isEqualToString: [bold familyName]]
    && ([[NSFontManager sharedFontManager] traitsOfFont: bold] & NSBoldFontMask) != 0)
    {
      [self pass: @"bold-font-family" detail: detail];
    }
  else
    {
      [self fail: @"bold-font-family" detail: detail];
    }
}

- (void) checkFirstWindows: (NSTimer *)timer
{
  [self saveWindow: _controlsWindow named: @"controls"];
  [self saveWindow: _toolbarWindow named: @"toolbar"];
  [self checkSizedButtons];
  [self checkLabels];
  [self checkToolbar];
  [self checkFonts];

  _lateWindow = [self windowWithFrame: NSMakeRect (480, 560, 300, 100) title: @"QuirkProbe Late Window"];
  [_lateWindow makeKeyAndOrderFront: nil];
  [self after: QuirkProbeSettleDelay perform: @selector(checkLateWindow:)];
}

- (void) checkLateWindow: (NSTimer *)timer
{
  NSMenu *mainMenu = [NSApp mainMenu];

  [self saveWindow: _lateWindow named: @"late-window"];
  if (NSInterfaceStyleForKey (@"NSMenuInterfaceStyle", nil) != NSWindows95InterfaceStyle)
    {
      [self skip: @"late-window-menu" detail: @"needs -NSMenuInterfaceStyle NSWindows95InterfaceStyle"];
    }
  else if ([_controlsWindow menu] != mainMenu)
    {
      [self fail: @"late-window-menu" detail: @"the first window has no menu either"];
    }
  else if ([_lateWindow menu] == mainMenu)
    {
      [self pass: @"late-window-menu" detail: @"a window created after launch shows the main menu"];
    }
  else
    {
      [self fail: @"late-window-menu" detail: @"a window created after launch has no menu"];
    }
  [self after: 0.1 perform: @selector(runAlert:)];
}

- (void) runAlert: (NSTimer *)timer
{
  NSAlert *alert = [[NSAlert alloc] init];

  [alert setMessageText: @"Remove this library?"];
  [alert setInformativeText: _alertText];
  [alert addButtonWithTitle: @"Remove"];
  [alert addButtonWithTitle: @"Cancel"];
  /* The alert runs a modal loop; the check fires inside it. */
  [self after: QuirkProbeSettleDelay perform: @selector(checkAlert:) mode: NSModalPanelRunLoopMode];
  [alert runModal];
  RELEASE (alert);
  [self finish];
}

- (void) checkAlert: (NSTimer *)timer
{
  NSWindow *panel = [NSApp modalWindow];
  NSView *text = QuirkProbeFindText ([panel contentView], _alertText);

  [self saveWindow: panel named: @"alert"];
  if (text == nil)
    {
      [self fail: @"alert-informative-text-wraps" detail: @"informative text view not found"];
    }
  else
    {
      [self checkLabel: text ident: @"alert-informative-text-wraps" lineHeight: [self lineHeight]];
    }
  /* -stopModal takes effect when the modal loop next handles an event. */
  [NSApp stopModal];
  [NSApp postEvent: [NSEvent otherEventWithType: NSApplicationDefined
                                       location: NSZeroPoint
                                  modifierFlags: 0
                                      timestamp: 0
                                   windowNumber: [panel windowNumber]
                                        context: nil
                                        subtype: 0
                                          data1: 0
                                          data2: 0]
           atStart: NO];
  [self after: 1.0 perform: @selector(forceEndAlert:) mode: NSModalPanelRunLoopMode];
}

/* Fallback when -stopModal hasn't ended the alert (seen with the default
   theme). */
- (void) forceEndAlert: (NSTimer *)timer
{
  if ([NSApp modalWindow] != nil)
    {
      [NSApp abortModal];
    }
}

- (void) finish
{
  printf ("SUMMARY pass=%lu fail=%lu known=%lu skip=%lu\n",
          (unsigned long)_passed, (unsigned long)_failed,
          (unsigned long)_known, (unsigned long)_skipped);
  fflush (stdout);
  exit (_failed > 255 ? 255 : (int)_failed);
}

#pragma mark Application delegate

- (void) applicationDidFinishLaunching: (NSNotification *)notification
{
  NSString *output = [[NSUserDefaults standardUserDefaults] stringForKey: @"ProbeOutput"];
  NSBundle *themeBundle = [[GSTheme theme] bundle];

  if ([output length] > 0)
    {
      ASSIGN (_outputDirectory, output);
      [[NSFileManager defaultManager] createDirectoryAtPath: output
                                withIntermediateDirectories: YES
                                                 attributes: nil
                                                      error: NULL];
    }
  printf ("THEME %s\n", themeBundle ? [[themeBundle bundlePath] UTF8String] : "(default)");
  printf ("THEMECLASS %s\n", [NSStringFromClass ([[GSTheme theme] class]) UTF8String]);
  fflush (stdout);

  [self buildWindows];
  [self after: QuirkProbeSettleDelay perform: @selector(checkFirstWindows:)];
}

@end
