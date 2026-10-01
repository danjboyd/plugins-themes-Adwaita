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
#import <GNUstepGUI/GSDragView.h>
#import <GNUstepGUI/GSDisplayServer.h>
#import <objc/runtime.h>
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
  NSInteger minX;
  NSInteger width;
  NSInteger height;
  NSUInteger count;
  NSUInteger darkest;   /* lowest red + green + blue among accepted pixels */
  NSInteger minY;
  NSUInteger lightest;  /* highest red + green + blue among accepted pixels */
} QuirkProbeInk;

typedef BOOL (*QuirkProbePixelTest)(NSUInteger red, NSUInteger green, NSUInteger blue);

/* Dark text on a light control: well below the Adwaita borders and fills,
   and below the accent blue, which only focus rings use here. */
static BOOL
QuirkProbeIsTextInk (NSUInteger red, NSUInteger green, NSUInteger blue)
{
  return (red + green + blue) < 306;
}

/* Anything visibly darker than a white background: dim text, grid lines,
   borders. */
static BOOL
QuirkProbeIsNotWhite (NSUInteger red, NSUInteger green, NSUInteger blue)
{
  return (red + green + blue) < 705;
}

/* White, or nearly: a text background rather than an Adwaita entry. */
static BOOL
QuirkProbeIsWhite (NSUInteger red, NSUInteger green, NSUInteger blue)
{
  return (red + green + blue) > 750;
}

/* Ink on the background whose red + green + blue is
   QuirkProbeInkBackground, whether the ink is darker or lighter: text and
   icons in any palette. */
static NSUInteger QuirkProbeInkBackground = 750;

static BOOL
QuirkProbeIsInk (NSUInteger red, NSUInteger green, NSUInteger blue)
{
  NSInteger difference = (NSInteger)(red + green + blue) - (NSInteger)QuirkProbeInkBackground;

  return difference > 150 || difference < -150;
}

/* How far the ink in `area` is from the background, at most. */
static NSUInteger
QuirkProbeContrast (QuirkProbeInk ink, NSUInteger background)
{
  if (ink.count == 0)
    {
      return 0;
    }
  return MAX (ink.lightest > background ? ink.lightest - background : 0,
              background > ink.darkest ? background - ink.darkest : 0);
}

/* Every pixel: for finding the darkest in an area. */
static BOOL
QuirkProbeIsAnyPixel (NSUInteger red, NSUInteger green, NSUInteger blue)
{
  return YES;
}

/* The toolbar test image is magenta, a colour the theme never draws. */
static BOOL
QuirkProbeIsMagenta (NSUInteger red, NSUInteger green, NSUInteger blue)
{
  return red > 200 && green < 80 && blue > 200;
}

/* The focus ring: the accent blue blended toward the window background. */
static BOOL
QuirkProbeIsFocusBlue (NSUInteger red, NSUInteger green, NSUInteger blue)
{
  return blue > 200 && blue > red + 30;
}

static NSBitmapImageRep *
QuirkProbeRender (NSView *view)
{
  NSRect bounds = [view bounds];
  NSBitmapImageRep *rep = [view bitmapImageRepForCachingDisplayInRect: bounds];

  [view cacheDisplayInRect: bounds toBitmapImageRep: rep];
  return rep;
}

/* Measures the accepted pixels in `area` (in pixels, top-left origin), or
   in the whole image when `area` is empty. */
static QuirkProbeInk
QuirkProbeMeasureIn (NSBitmapImageRep *rep, QuirkProbePixelTest test, NSRect area)
{
  QuirkProbeInk ink = { 0, 0, 0, 0, NSUIntegerMax, 0, 0 };
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
  NSInteger startX = 0, startY = 0;
  NSInteger endX = [rep pixelsWide], endY = [rep pixelsHigh];

  if (samples < 3 || samples > 5)
    {
      return ink;
    }
  if (NSIsEmptyRect (area) == NO)
    {
      startX = MAX (0, (NSInteger)NSMinX (area));
      startY = MAX (0, (NSInteger)NSMinY (area));
      endX = MIN (endX, (NSInteger)NSMaxX (area));
      endY = MIN (endY, (NSInteger)NSMaxY (area));
    }
  for (y = startY; y < endY; y++)
    {
      for (x = startX; x < endX; x++)
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
              ink.darkest = MIN (ink.darkest, red + green + blue);
              ink.lightest = MAX (ink.lightest, red + green + blue);
              minX = MIN (minX, x);
              maxX = MAX (maxX, x);
              minY = MIN (minY, y);
              maxY = MAX (maxY, y);
            }
        }
    }
  if (ink.count > 0)
    {
      ink.minX = minX;
      ink.width = maxX - minX + 1;
      ink.height = maxY - minY + 1;
      ink.minY = minY;
    }
  return ink;
}

static QuirkProbeInk
QuirkProbeMeasure (NSBitmapImageRep *rep, QuirkProbePixelTest test)
{
  return QuirkProbeMeasureIn (rep, test, NSZeroRect);
}

static QuirkProbeInk
QuirkProbeTextInk (NSView *view)
{
  return QuirkProbeMeasure (QuirkProbeRender (view), QuirkProbeIsTextInk);
}

static NSView *
QuirkProbeFindViewOfClass (NSView *view, Class viewClass)
{
  NSEnumerator *enumerator;
  NSView *subview;

  if (viewClass == Nil || [view isKindOfClass: viewClass])
    {
      return (viewClass == Nil) ? nil : view;
    }
  enumerator = [[view subviews] objectEnumerator];
  while ((subview = [enumerator nextObject]) != nil)
    {
      NSView *found = QuirkProbeFindViewOfClass (subview, viewClass);

      if (found != nil)
        {
          return found;
        }
    }
  return nil;
}

/* Sends the window a mouse-moved event at `point` (window coordinates), as
   the pointer would; tracking rects fire from these. */
static void
QuirkProbeMoveMouse (NSWindow *window, NSPoint point)
{
  NSEvent *event = [NSEvent mouseEventWithType: NSMouseMoved
                                      location: point
                                 modifierFlags: 0
                                     timestamp: 0
                                  windowNumber: [window windowNumber]
                                       context: nil
                                   eventNumber: 0
                                    clickCount: 0
                                      pressure: 0.0];

  [window sendEvent: event];
  /* Renders come from the window's backing store: draw what the event
     invalidated first. */
  [window displayIfNeeded];
}

/* Moves the pointer as QuirkProbeMoveMouse does, then delivers the cursor
   updates that entering or leaving cursor rects posts to the queue, so
   [NSCursor currentCursor] shows the result. */
static void
QuirkProbeMoveMouseForCursor (NSWindow *window, NSPoint point)
{
  NSEvent *update;

  QuirkProbeMoveMouse (window, point);
  while ((update = [NSApp nextEventMatchingMask: NSCursorUpdateMask
                                      untilDate: [NSDate distantPast]
                                         inMode: NSDefaultRunLoopMode
                                        dequeue: YES]) != nil)
    {
      [NSApp sendEvent: update];
    }
}

/* Sends an event through NSApp, as a real key or pointer press arrives. */
static void
QuirkProbeSendApplicationEvent (NSWindow *window, NSEventType type)
{
  NSEvent *event;

  if (type == NSKeyDown)
    {
      /* F13: no control or key binding uses it. */
      NSString *key = [NSString stringWithFormat: @"%C", (unichar)NSF13FunctionKey];

      event = [NSEvent keyEventWithType: NSKeyDown
                               location: NSZeroPoint
                          modifierFlags: 0
                              timestamp: 0
                           windowNumber: [window windowNumber]
                                context: nil
                             characters: key
            charactersIgnoringModifiers: key
                              isARepeat: NO
                                keyCode: 0];
    }
  else
    {
      /* On the window background, clear of any control. */
      event = [NSEvent mouseEventWithType: type
                                 location: NSMakePoint (5, 5)
                            modifierFlags: 0
                                timestamp: 0
                             windowNumber: [window windowNumber]
                                  context: nil
                              eventNumber: 0
                               clickCount: 1
                                 pressure: 1.0];
    }
  [NSApp sendEvent: event];
  [window displayIfNeeded];
}

/* YES when GNUstep draws the window decorations (-GSX11HandlesWindowDecorations
   NO), so the theme draws its header bar. */
static BOOL
QuirkProbeDrawsDecorations (void)
{
  return [GSCurrentServer () handlesWindowDecorations] == NO;
}

/* How far below the top of `view` a subview's `frame` starts. */
static CGFloat
QuirkProbeTopGap (NSView *view, NSRect frame)
{
  return [view isFlipped] ? NSMinY (frame) : NSMaxY ([view bounds]) - NSMaxY (frame);
}

/* The header bar's window buttons, left to right. */
static NSArray *
QuirkProbeWindowButtons (NSView *frameView)
{
  NSMutableArray *buttons = [NSMutableArray array];
  NSEnumerator *enumerator = [[frameView subviews] objectEnumerator];
  NSView *subview;
  NSUInteger i, j;

  while ((subview = [enumerator nextObject]) != nil)
    {
      if ([subview isKindOfClass: NSClassFromString (@"GnomeThemeWindowButton")] && [subview isHidden] == NO)
        {
          [buttons addObject: subview];
        }
    }
  for (i = 1; i < [buttons count]; i++)
    {
      for (j = i; j > 0 && NSMinX ([[buttons objectAtIndex: j] frame]) < NSMinX ([[buttons objectAtIndex: j - 1] frame]); j--)
        {
          [buttons exchangeObjectAtIndex: j withObjectAtIndex: j - 1];
        }
    }
  return buttons;
}

/* A click in `window` at `point` (window coordinates), sent through NSApp. */
static void
QuirkProbeClick (NSWindow *window, NSPoint point, NSInteger clickCount)
{
  NSEvent *event = [NSEvent mouseEventWithType: NSLeftMouseDown
                                      location: point
                                 modifierFlags: 0
                                     timestamp: 0
                                  windowNumber: [window windowNumber]
                                       context: nil
                                   eventNumber: 0
                                    clickCount: clickCount
                                      pressure: 1.0];

  [NSApp sendEvent: event];
  [window displayIfNeeded];
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

/* A toolbar delegate whose items select a view, like Gorm's document
   toolbar. */
@interface QuirkProbeSwitcherDelegate : NSObject
@end

@implementation QuirkProbeSwitcherDelegate
- (NSToolbarItem *) toolbar: (NSToolbar *)toolbar
      itemForItemIdentifier: (NSString *)identifier
  willBeInsertedIntoToolbar: (BOOL)flag
{
  NSToolbarItem *item = AUTORELEASE ([[NSToolbarItem alloc] initWithItemIdentifier: identifier]);

  [item setLabel: identifier];
  return item;
}
- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *)toolbar
{
  return [NSArray arrayWithObjects: @"Objects", @"Classes", nil];
}
- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *)toolbar
{
  return [self toolbarAllowedItemIdentifiers: toolbar];
}
- (NSArray *) toolbarSelectableItemIdentifiers: (NSToolbar *)toolbar
{
  return [self toolbarAllowedItemIdentifiers: toolbar];
}
@end

/* Ink per row, top to bottom, over the rows that have any: the text's
   vertical profile. */
static NSArray *
QuirkProbeInkRows (NSBitmapImageRep *rep, NSRect area)
{
  NSMutableArray *rows = [NSMutableArray array];
  NSInteger y;

  for (y = (NSInteger)NSMinY (area); y < (NSInteger)NSMaxY (area) && y < [rep pixelsHigh]; y++)
    {
      QuirkProbeInk row = QuirkProbeMeasureIn (rep, QuirkProbeIsTextInk,
                                               NSMakeRect (NSMinX (area), y, NSWidth (area), 1));

      if (row.count > 0 || [rows count] > 0)
        {
          [rows addObject: [NSNumber numberWithUnsignedInteger: row.count]];
        }
    }
  while ([rows count] > 0 && [[rows lastObject] unsignedIntegerValue] == 0)
    {
      [rows removeLastObject];
    }
  return rows;
}

/* How far apart two profiles are, the second read top down or (reversed)
   bottom up. */
static NSUInteger
QuirkProbeProfileDistance (NSArray *a, NSArray *b, BOOL reversed)
{
  NSUInteger count = MIN ([a count], [b count]);
  NSUInteger i, distance = 0;

  for (i = 0; i < count; i++)
    {
      NSInteger x = [[a objectAtIndex: i] integerValue];
      NSInteger y = [[b objectAtIndex: reversed ? [b count] - 1 - i : i] integerValue];

      distance += (NSUInteger)labs (x - y);
    }
  return distance + (MAX ([a count], [b count]) - count) * 10;
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
- (void) checkPrimaryMenuInMenuBar;
- (void) checkPrimaryMenuInHeaderBar;
@end

@implementation QuirkProbe

- (id) init
{
  self = [super init];
  if (self != nil)
    {
      _windows = [NSMutableArray new];
      _sizedButtons = [NSMutableArray new];
      _fixedButtons = [NSMutableArray new];
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
  RELEASE (_fixedButtons);
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

#pragma mark Table data source

- (NSInteger) numberOfRowsInTableView: (NSTableView *)tableView
{
  return 4;
}

- (id) tableView: (NSTableView *)tableView
objectValueForTableColumn: (NSTableColumn *)column
             row: (NSInteger)row
{
  return [NSString stringWithFormat: @"Library %ld", (long)row + 1];
}

#pragma mark Windows

- (NSTableView *) addTableAt: (NSRect)frame inView: (NSView *)view
{
  NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame: frame];
  NSTableView *tableView = [[NSTableView alloc] initWithFrame:
    NSMakeRect (0, 0, NSWidth (frame), NSHeight (frame))];
  NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier: @"name"];

  [[column headerCell] setStringValue: @"Name"];
  [column setWidth: NSWidth (frame) - 10];
  [tableView addTableColumn: column];
  [tableView setDataSource: self];
  [scrollView setDocumentView: tableView];
  [scrollView setBorderType: NSBezelBorder];
  [scrollView setHasVerticalScroller: NO];
  [scrollView setHasHorizontalScroller: NO];
  [view addSubview: scrollView];
  [tableView reloadData];
  RELEASE (column);
  RELEASE (scrollView);
  return AUTORELEASE (tableView);
}

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

/* A push button of a size the app chose, too small for the theme's full
   padding but with room for its title, beside a wide copy as the reference
   (in a column of their own at x 700). */
- (void) addFixedButtonTitled: (NSString *)title
                        frame: (NSRect)frame
                       inView: (NSView *)view
{
  NSButton *fixed = [[NSButton alloc] initWithFrame: frame];
  NSButton *wide = [[NSButton alloc] initWithFrame: NSMakeRect (700, 140 - 40 * [_fixedButtons count],
                                                               180, NSHeight (frame))];
  NSEnumerator *enumerator = [[NSArray arrayWithObjects: fixed, wide, nil] objectEnumerator];
  NSButton *button;

  while ((button = [enumerator nextObject]) != nil)
    {
      [button setButtonType: NSMomentaryPushInButton];
      [button setBezelStyle: NSRoundedBezelStyle];
      [button setTitle: title];
      [view addSubview: button];
    }
  [_fixedButtons addObject: [NSArray arrayWithObjects: fixed, wide, nil]];
  RELEASE (fixed);
  RELEASE (wide);
}

- (NSStepper *) stepperWithFrame: (NSRect)frame value: (double)value inView: (NSView *)view
{
  NSStepper *stepper = [[NSStepper alloc] initWithFrame: frame];

  [stepper setMinValue: 0];
  [stepper setMaxValue: 10];
  [stepper setDoubleValue: value];
  [view addSubview: stepper];
  return AUTORELEASE (stepper);
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
  /* ScreenshotTool's quick-width buttons (plugins-themes-Adwaita#3). */
  [self addFixedButtonTitled: @"12" frame: NSMakeRect (250, 130, 64, 28) inView: view];
  [self addFixedButtonTitled: @"20" frame: NSMakeRect (330, 130, 44, 28) inView: view];
  [self addFixedButtonTitled: @"Apply" frame: NSMakeRect (250, 90, 64, 28) inView: view];
  /* Steppers: Cocoa's size, the same at its maximum, and a wide one
     (plugins-themes-Adwaita#6). */
  _tallStepper = [self stepperWithFrame: NSMakeRect (400, 100, 18, 24) value: 5 inView: view];
  _maxedStepper = [self stepperWithFrame: NSMakeRect (430, 100, 18, 24) value: 10 inView: view];
  [_maxedStepper setValueWraps: NO];
  _wideStepper = [self stepperWithFrame: NSMakeRect (400, 60, 48, 24) value: 5 inView: view];
  /* A colour well (plugins-themes-Adwaita#2). */
  _colorWell = AUTORELEASE ([[NSColorWell alloc] initWithFrame: NSMakeRect (480, 140, 52, 30)]);
  [_colorWell setColor: [NSColor colorWithCalibratedRed: 0.9 green: 0.1 blue: 0.1 alpha: 1.0]];
  [view addSubview: _colorWell];

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

  _popUpButton = [[NSPopUpButton alloc] initWithFrame: NSMakeRect (10, 60, 220, 30) pullsDown: NO];
  [_popUpButton addItemsWithTitles: [NSArray arrayWithObjects: @"Personal account", @"Work or school", nil]];
  [view addSubview: _popUpButton];
  RELEASE (_popUpButton);

  [_controlsWindow makeKeyAndOrderFront: nil];

  _toolbarWindow = [self windowWithFrame: NSMakeRect (40, 560, 400, 120) title: @"QuirkProbe Toolbar"];
  toolbar = [[NSToolbar alloc] initWithIdentifier: @"QuirkProbe"];
  [toolbar setDelegate: self];
  [toolbar setDisplayMode: NSToolbarDisplayModeIconAndLabel];
  [_toolbarWindow setToolbar: toolbar];
  RELEASE (toolbar);
  [_toolbarWindow orderFront: nil];

  /* Two tables: one left at GNUstep's default grid setting, one whose app
     asked for horizontal grid lines. */
  _tableWindow = [self windowWithFrame: NSMakeRect (960, 40, 300, 330) title: @"QuirkProbe Tables"];
  view = [_tableWindow contentView];
  _defaultGridTable = [self addTableAt: NSMakeRect (20, 170, 260, 140) inView: view];
  _explicitGridTable = [self addTableAt: NSMakeRect (20, 10, 260, 140) inView: view];
  [_explicitGridTable setGridStyleMask: NSTableViewSolidHorizontalGridLineMask];
  [_tableWindow orderFront: nil];

  /* A window with every window button, for the header bar checks. */
  if (QuirkProbeDrawsDecorations ())
    {
      _headerWindow = [[NSWindow alloc] initWithContentRect: NSMakeRect (480, 200, 420, 160)
                                                  styleMask: (NSTitledWindowMask | NSClosableWindowMask
                                                              | NSMiniaturizableWindowMask | NSResizableWindowMask)
                                                    backing: NSBackingStoreBuffered
                                                      defer: NO];
      [_headerWindow setTitle: @"QuirkProbe Header Bar"];
      [_headerWindow setReleasedWhenClosed: NO];
      [_windows addObject: _headerWindow];
      RELEASE (_headerWindow);
      [_headerWindow orderFront: nil];
    }
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

/* A button narrower than the theme's padding wants still draws its whole
   title when there's room for it. */
- (void) checkFixedButtons
{
  NSEnumerator *enumerator = [_fixedButtons objectEnumerator];
  NSArray *pair;

  while ((pair = [enumerator nextObject]) != nil)
    {
      NSButton *fixed = [pair objectAtIndex: 0];
      QuirkProbeInk fixedInk = QuirkProbeTextInk (fixed);
      QuirkProbeInk wideInk = QuirkProbeTextInk ([pair objectAtIndex: 1]);
      NSString *ident = [NSString stringWithFormat: @"fixed-width-title \"%@\"", [fixed title]];
      NSString *detail = [NSString stringWithFormat: @"title ink %ldx%ld in %gx%gpt, %ldx%ld with room to spare",
        (long)fixedInk.width, (long)fixedInk.height, NSWidth ([fixed frame]), NSHeight ([fixed frame]),
        (long)wideInk.width, (long)wideInk.height];

      if (wideInk.count == 0)
        {
          [self fail: ident detail: @"reference button drew no title"];
        }
      else if (fixedInk.width + 1 >= wideInk.width
        && ABS (fixedInk.height - wideInk.height) <= 1)
        {
          [self pass: ident detail: detail];
        }
      else
        {
          [self fail: ident detail: [detail stringByAppendingString: @" (clipped)"]];
        }
    }
}

static BOOL
QuirkProbeIsRed (NSUInteger red, NSUInteger green, NSUInteger blue)
{
  return red > 180 && green < 80 && blue < 80;
}

/* A glyph's antialiased strokes on a control's fill. */
static BOOL
QuirkProbeIsGlyphInk (NSUInteger red, NSUInteger green, NSUInteger blue)
{
  return (red + green + blue) < 600;
}

/* Glyph ink in each half of a stepper, from the theme's own button rects
   (as NSStepperCell hit-tests them), in the render's top-left pixels. */
- (void) measureStepper: (NSStepper *)stepper up: (QuirkProbeInk *)up down: (QuirkProbeInk *)down
{
  GSTheme *theme = [GSTheme theme];
  NSRect bounds = [stepper bounds];
  NSBitmapImageRep *rep = QuirkProbeRender (stepper);
  NSRect upRect = [theme stepperUpButtonRectWithFrame: bounds];
  NSRect downRect = [theme stepperDownButtonRectWithFrame: bounds];

  if ([stepper isFlipped] == NO)
    {
      upRect.origin.y = NSHeight (bounds) - NSMaxY (upRect);
      downRect.origin.y = NSHeight (bounds) - NSMaxY (downRect);
    }
  *up = QuirkProbeMeasureIn (rep, QuirkProbeIsGlyphInk, upRect);
  *down = QuirkProbeMeasureIn (rep, QuirkProbeIsGlyphInk, downRect);
}

- (void) checkSteppers
{
  GSTheme *theme = [GSTheme theme];
  NSRect bounds = [_tallStepper bounds];
  NSRect upRect = [theme stepperUpButtonRectWithFrame: bounds];
  NSRect downRect = [theme stepperDownButtonRectWithFrame: bounds];
  QuirkProbeInk up, down;
  NSString *detail;
  CGFloat middle = NSWidth (bounds) / 2.0;

  /* A Cocoa-sized stepper: an up half above a down half, each with a glyph
     in the middle. */
  [self measureStepper: _tallStepper up: &up down: &down];
  detail = [NSString stringWithFormat: @"%gx%g: up half %@ (ink %ldx%ld at x %ld), down half %@ (ink %ldx%ld at x %ld)",
    NSWidth (bounds), NSHeight (bounds), NSStringFromRect (upRect),
    (long)up.width, (long)up.height, (long)up.minX, NSStringFromRect (downRect),
    (long)down.width, (long)down.height, (long)down.minX];
  if (NSMinY (upRect) >= NSMaxY (downRect) && NSWidth (upRect) == NSWidth (bounds)
    && up.count > 0 && down.count > 0
    && ABS (up.minX + up.width / 2.0 - middle) <= 1.5
    && ABS (down.minX + down.width / 2.0 - middle) <= 1.5)
    {
      [self pass: @"stepper-vertical" detail: detail];
    }
  else
    {
      [self fail: @"stepper-vertical" detail: detail];
    }

  /* At its maximum, the up half is dimmed, as GTK's spin button. */
  [self measureStepper: _maxedStepper up: &up down: &down];
  detail = [NSString stringWithFormat: @"at the maximum: darkest up glyph pixel %lu, down %lu (r+g+b)",
    (unsigned long)up.darkest, (unsigned long)down.darkest];
  if (down.count > 0 && (up.count == 0 || up.darkest > down.darkest + 100))
    {
      [self pass: @"stepper-dims-at-limit" detail: detail];
    }
  else
    {
      [self fail: @"stepper-dims-at-limit" detail: detail];
    }

  /* A wide stepper keeps − and + side by side. */
  bounds = [_wideStepper bounds];
  upRect = [theme stepperUpButtonRectWithFrame: bounds];
  downRect = [theme stepperDownButtonRectWithFrame: bounds];
  [self measureStepper: _wideStepper up: &up down: &down];
  detail = [NSString stringWithFormat: @"%gx%g: up %@ (ink %ldx%ld), down %@ (ink %ldx%ld)",
    NSWidth (bounds), NSHeight (bounds), NSStringFromRect (upRect), (long)up.width, (long)up.height,
    NSStringFromRect (downRect), (long)down.width, (long)down.height];
  if (NSMinX (upRect) >= NSMaxX (downRect) && up.count > 0 && down.count > 0
    && up.height > down.height)
    {
      [self pass: @"stepper-wide-horizontal" detail: detail];
    }
  else
    {
      [self fail: @"stepper-wide-horizontal" detail: detail];
    }
}

/* A colour well as GTK's colour button: the colour in a rounded swatch inset
   in a flat button, not NeXT's dark bevel. */
- (void) checkColorWell
{
  NSBitmapImageRep *rep = QuirkProbeRender (_colorWell);
  NSRect bounds = [_colorWell bounds];
  QuirkProbeInk swatch = QuirkProbeMeasure (rep, QuirkProbeIsRed);
  QuirkProbeInk corner, edge;
  NSString *detail;

  if (swatch.count == 0)
    {
      [self fail: @"colorwell-adwaita" detail: @"no swatch drawn"];
      return;
    }
  corner = QuirkProbeMeasureIn (rep, QuirkProbeIsRed, NSMakeRect (swatch.minX, swatch.minY, 2, 2));
  edge = QuirkProbeMeasureIn (rep, QuirkProbeIsAnyPixel, NSMakeRect (0, 0, swatch.minX, NSHeight (bounds)));
  detail = [NSString stringWithFormat: @"swatch %ldx%ld at %ld,%ld in %gx%g; %lu red pixels in its corner; "
    @"darkest pixel left of it %lu",
    (long)swatch.width, (long)swatch.height, (long)swatch.minX, (long)swatch.minY,
    NSWidth (bounds), NSHeight (bounds), (unsigned long)corner.count, (unsigned long)edge.darkest];
  if (swatch.minX >= 4 && swatch.minY >= 3 && corner.count < 4 && edge.darkest > 450)
    {
      [self pass: @"colorwell-adwaita" detail: detail];
    }
  else
    {
      [self fail: @"colorwell-adwaita" detail: detail];
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

/* Pixels on the boundary lines between rows 0-1, 1-2 and 2-3 that are
   darker than the white row background, in the right half of the table
   (clear of the rows' text and its descenders). */
- (NSUInteger) gridPixelsInTable: (NSTableView *)tableView
{
  NSBitmapImageRep *rep = QuirkProbeRender (tableView);
  NSUInteger count = 0;
  NSInteger row;

  for (row = 0; row < 3; row++)
    {
      NSInteger y = (NSInteger)NSMaxY ([tableView rectOfRow: row]) - 1;

      count += QuirkProbeMeasureIn (rep, QuirkProbeIsNotWhite,
                                    NSMakeRect ([rep pixelsWide] / 2, y, [rep pixelsWide] / 2, 1)).count;
    }
  return count;
}

- (void) checkTables
{
  NSUInteger defaultGrid = [self gridPixelsInTable: _defaultGridTable];
  NSUInteger explicitGrid = [self gridPixelsInTable: _explicitGridTable];
  NSInteger width = (NSInteger)NSWidth ([_defaultGridTable bounds]);
  NSScrollView *scrollView = [_defaultGridTable enclosingScrollView];
  NSBitmapImageRep *scrollRep = QuirkProbeRender (scrollView);
  NSInteger scrollWidth = [scrollRep pixelsWide];
  NSInteger scrollHeight = [scrollRep pixelsHigh];
  NSUInteger framePixels = 0;
  NSTableHeaderView *headerView = [_defaultGridTable headerView];
  QuirkProbeInk headerInk = QuirkProbeMeasure (QuirkProbeRender (headerView), QuirkProbeIsNotWhite);
  QuirkProbeInk rowInk = QuirkProbeMeasure (QuirkProbeRender (_defaultGridTable), QuirkProbeIsNotWhite);
  NSString *detail;

  detail = [NSString stringWithFormat: @"%lu grid pixels on 3 half-row boundaries",
    (unsigned long)defaultGrid];
  if (defaultGrid == 0)
    {
      [self pass: @"table-grid-default" detail: detail];
    }
  else
    {
      [self fail: @"table-grid-default"
          detail: [detail stringByAppendingString: @" (GNUstep's default grid should draw none)"]];
    }

  detail = [NSString stringWithFormat: @"%lu grid pixels on 3 half-row boundaries of %ldpt",
    (unsigned long)explicitGrid, (long)width / 2];
  if (explicitGrid >= (NSUInteger)width * 3 / 4)
    {
      [self pass: @"table-grid-explicit" detail: detail];
    }
  else
    {
      [self fail: @"table-grid-explicit"
          detail: [detail stringByAppendingString: @" (asked-for grid lines missing)"]];
    }

  /* The scroll view's outermost ring of pixels. */
  framePixels += QuirkProbeMeasureIn (scrollRep, QuirkProbeIsNotWhite, NSMakeRect (0, 0, scrollWidth, 1)).count;
  framePixels += QuirkProbeMeasureIn (scrollRep, QuirkProbeIsNotWhite, NSMakeRect (0, scrollHeight - 1, scrollWidth, 1)).count;
  framePixels += QuirkProbeMeasureIn (scrollRep, QuirkProbeIsNotWhite, NSMakeRect (0, 0, 1, scrollHeight)).count;
  framePixels += QuirkProbeMeasureIn (scrollRep, QuirkProbeIsNotWhite, NSMakeRect (scrollWidth - 1, 0, 1, scrollHeight)).count;
  detail = [NSString stringWithFormat: @"%lu frame pixels around a bezel-bordered table", (unsigned long)framePixels];
  if (framePixels == 0)
    {
      [self pass: @"table-no-frame" detail: detail];
    }
  else
    {
      [self fail: @"table-no-frame" detail: detail];
    }

  detail = [NSString stringWithFormat: @"header text starts at %ldpt, rows at %ldpt; darkest header %lu, rows %lu",
    (long)headerInk.minX, (long)rowInk.minX,
    (unsigned long)headerInk.darkest, (unsigned long)rowInk.darkest];
  if (headerInk.count > 0 && rowInk.count > 0
    && ABS (headerInk.minX - rowInk.minX) <= 2
    && headerInk.darkest >= rowInk.darkest + 120)
    {
      [self pass: @"table-header" detail: detail];
    }
  else
    {
      [self fail: @"table-header"
          detail: [detail stringByAppendingString: @" (want left-aligned with the rows, and dimmer)"]];
    }
}

/* GNOME apps have no menu named after the app; an empty one (this probe's:
   its only menu is File) should be gone. */
- (void) checkMenuBar
{
  NSMenu *mainMenu = [NSApp mainMenu];
  NSString *first = ([mainMenu numberOfItems] > 0) ? [[mainMenu itemAtIndex: 0] title] : @"";
  NSString *detail = [NSString stringWithFormat: @"first menu bar item \"%@\"", first];

  if (NSInterfaceStyleForKey (@"NSMenuInterfaceStyle", nil) != NSWindows95InterfaceStyle)
    {
      [self skip: @"menubar-no-empty-app-item" detail: @"needs -NSMenuInterfaceStyle NSWindows95InterfaceStyle"];
    }
  else if ([first isEqualToString: [[NSProcessInfo processInfo] processName]])
    {
      [self fail: @"menubar-no-empty-app-item" detail: [detail stringByAppendingString: @" (empty app menu shown)"]];
    }
  else
    {
      [self pass: @"menubar-no-empty-app-item" detail: detail];
    }
}

/* No dark line across the menu bar and toolbar (GSTheme's fallback toolbar
   border is dark grey). */
- (void) checkToolbarEdges
{
  NSView *frameView = [[_toolbarWindow contentView] superview];
  NSView *toolbarView = QuirkProbeFindViewOfClass (frameView, NSClassFromString (@"GSToolbarView"));
  NSBitmapImageRep *rep = QuirkProbeRender (frameView);
  NSInteger bottom = 120;
  QuirkProbeInk dark;
  NSString *detail;

  if (toolbarView != nil)
    {
      NSRect frame = [toolbarView convertRect: [toolbarView bounds] toView: frameView];

      bottom = (NSInteger)([frameView isFlipped] ? NSMaxY (frame) : NSHeight ([frameView bounds]) - NSMinY (frame)) + 2;
    }
  /* A column clear of the toolbar items, from the top to just below the
     toolbar. */
  dark = QuirkProbeMeasureIn (rep, QuirkProbeIsTextInk,
                              NSMakeRect ([rep pixelsWide] - 5, 0, 1, bottom));
  detail = [NSString stringWithFormat: @"%lu dark pixels in the top %ldpt of the right edge",
    (unsigned long)dark.count, (long)bottom];
  if (dark.count == 0)
    {
      [self pass: @"toolbar-edges-light" detail: detail];
    }
  else
    {
      [self fail: @"toolbar-edges-light" detail: detail];
    }
}

/* Moving the pointer over an image toolbar button shows the hover
   background. */
- (void) checkToolbarHover
{
  NSView *frameView = [[_toolbarWindow contentView] superview];
  NSView *button = QuirkProbeFindViewOfClass (frameView, NSClassFromString (@"GSToolbarButton"));
  NSRect inWindow;
  NSUInteger before, after;
  NSRect edge;

  if (button == nil)
    {
      [self fail: @"toolbar-hover" detail: @"no toolbar button found"];
      return;
    }
  /* A strip along the left edge, clear of the icon and label. */
  edge = NSMakeRect (3, NSHeight ([button bounds]) / 2 - 5, 4, 10);
  inWindow = [button convertRect: [button bounds] toView: nil];
  QuirkProbeMoveMouse (_toolbarWindow, NSMakePoint (NSMaxX (inWindow) + 150, NSMinY (inWindow) - 30));
  before = QuirkProbeMeasureIn (QuirkProbeRender (button), QuirkProbeIsAnyPixel, edge).darkest;
  QuirkProbeMoveMouse (_toolbarWindow, NSMakePoint (NSMidX (inWindow), NSMidY (inWindow)));
  after = QuirkProbeMeasureIn (QuirkProbeRender (button), QuirkProbeIsAnyPixel, edge).darkest;
  QuirkProbeMoveMouse (_toolbarWindow, NSMakePoint (NSMaxX (inWindow) + 150, NSMinY (inWindow) - 30));

  if (after + 20 <= before)
    {
      [self pass: @"toolbar-hover"
          detail: [NSString stringWithFormat: @"background %lu away from the pointer, %lu under it",
                     (unsigned long)before, (unsigned long)after]];
    }
  else
    {
      [self fail: @"toolbar-hover"
          detail: [NSString stringWithFormat: @"background %lu away from the pointer, %lu under it (no hover)",
                     (unsigned long)before, (unsigned long)after]];
    }
}

/* A pop-up button's title starts near its left edge (the originals of the
   theme's NSMenuItemCell overrides would put it about 50pt in). */
- (void) checkPopUpButton
{
  QuirkProbeInk ink = QuirkProbeTextInk (_popUpButton);
  NSString *detail = [NSString stringWithFormat: @"title starts %ldpt from the left edge", (long)ink.minX];

  if (ink.count > 0 && ink.minX <= 24)
    {
      [self pass: @"popup-title-position" detail: detail];
    }
  else
    {
      [self fail: @"popup-title-position" detail: detail];
    }
}

/* A focused push button, as in OneDriveServiceManager's Resync panel, where
   Cancel is the first key view. As in GTK, the ring shows only after a key
   press. It runs along the button's edge: not around the title (where NSCell
   put a second ring) and not in the corners outside the rounded fill (all
   that showed of a ring drawn outside the frame). */
- (void) checkButtonFocusRing
{
  NSWindow *window = [self windowWithFrame: NSMakeRect (480, 700, 200, 60) title: @"QuirkProbe Focus"];
  NSButton *button = [[NSButton alloc] initWithFrame: NSMakeRect (40, 15, 120, 30)];
  NSRect bounds;
  NSRect inner;
  QuirkProbeInk afterClick, afterKey, title, corner;
  NSString *detail;

  [button setTitle: @"Cancel"];
  [button setBezelStyle: NSRoundedBezelStyle];
  [button setKeyEquivalent: @"\e"];
  [[window contentView] addSubview: button];
  RELEASE (button);
  [window makeKeyAndOrderFront: nil];
  [window makeFirstResponder: button];
  bounds = [button bounds];
  inner = NSInsetRect (bounds, 5, 5);

  QuirkProbeSendApplicationEvent (window, NSLeftMouseDown);
  QuirkProbeSendApplicationEvent (window, NSLeftMouseUp);
  afterClick = QuirkProbeMeasure (QuirkProbeRender (button), QuirkProbeIsFocusBlue);
  QuirkProbeSendApplicationEvent (window, NSKeyDown);
  afterKey = QuirkProbeMeasure (QuirkProbeRender (button), QuirkProbeIsFocusBlue);
  title = QuirkProbeMeasureIn (QuirkProbeRender (button), QuirkProbeIsFocusBlue, inner);
  corner = QuirkProbeMeasureIn (QuirkProbeRender (button), QuirkProbeIsFocusBlue, NSMakeRect (0, 0, 2, 2));
  [self saveWindow: window named: @"button-focus"];
  /* Leave focus-visible off for later checks. */
  QuirkProbeSendApplicationEvent (window, NSLeftMouseDown);
  QuirkProbeSendApplicationEvent (window, NSLeftMouseUp);
  [window orderOut: nil];

  detail = [NSString stringWithFormat: @"ring pixels: %lu after a click, %lu after a key "
    @"(%ldx%ld of %gx%g), %lu around the title, %lu in the corner",
    (unsigned long)afterClick.count, (unsigned long)afterKey.count,
    (long)afterKey.width, (long)afterKey.height, NSWidth (bounds), NSHeight (bounds),
    (unsigned long)title.count, (unsigned long)corner.count];
  if (afterClick.count == 0 && afterKey.count > 0
    && afterKey.width + 4 >= NSWidth (bounds) && afterKey.height + 4 >= NSHeight (bounds)
    && title.count == 0 && corner.count == 0)
    {
      [self pass: @"button-focus-ring" detail: detail];
    }
  else
    {
      [self fail: @"button-focus-ring" detail: detail];
    }
}

/* The label starts about 5px after a checkbox's indicator, as in GTK. */
- (void) checkCheckboxGap
{
  NSEnumerator *enumerator = [_sizedButtons objectEnumerator];
  NSArray *pair;

  while ((pair = [enumerator nextObject]) != nil)
    {
      NSButton *button = [pair objectAtIndex: 0];
      NSBitmapImageRep *rep;
      QuirkProbeInk text, indicator;
      NSInteger gap;
      NSString *detail;

      if ([[button title] isEqualToString: @"Errors only"] == NO)
        {
          continue;
        }
      rep = QuirkProbeRender (button);
      text = QuirkProbeMeasure (rep, QuirkProbeIsTextInk);
      indicator = QuirkProbeMeasureIn (rep, QuirkProbeIsNotWhite,
                                       NSMakeRect (0, 0, text.minX - 1, [rep pixelsHigh]));
      gap = text.minX - (indicator.minX + indicator.width);
      detail = [NSString stringWithFormat: @"indicator %ldpx wide, label %ldpx after it",
        (long)indicator.width, (long)gap];
      if (text.count > 0 && indicator.count > 0 && gap >= 3 && gap <= 7)
        {
          [self pass: @"checkbox-label-gap" detail: detail];
        }
      else
        {
          [self fail: @"checkbox-label-gap" detail: detail];
        }
      return;
    }
  [self fail: @"checkbox-label-gap" detail: @"checkbox not found"];
}

/* A table built in code gets GTK's list density; one the app sized keeps
   its rows. */
- (void) checkTableDensity
{
  NSTableView *plain = AUTORELEASE ([[NSTableView alloc] initWithFrame: NSMakeRect (0, 0, 100, 100)]);
  NSTableView *sized = AUTORELEASE ([[NSTableView alloc] initWithFrame: NSMakeRect (0, 0, 100, 100)]);
  NSString *detail;

  [sized setRowHeight: 22.0];
  detail = [NSString stringWithFormat: @"default rows %gpt, spacing %@; app-sized rows %gpt",
    [plain rowHeight], NSStringFromSize ([plain intercellSpacing]), [sized rowHeight]];
  if ([plain rowHeight] >= 34.0 && NSEqualSizes ([plain intercellSpacing], NSZeroSize)
    && [sized rowHeight] == 22.0)
    {
      [self pass: @"table-row-density" detail: detail];
    }
  else
    {
      [self fail: @"table-row-density" detail: detail];
    }
}

/* Top tabs are flat, GtkNotebook style: only the selected tab is marked, by
   a 4px accent underline at the bottom of the tab strip. */
- (void) checkTabView
{
  NSWindow *window = [self windowWithFrame: NSMakeRect (700, 700, 360, 120) title: @"QuirkProbe Tabs"];
  NSTabView *tabView = [[NSTabView alloc] initWithFrame: NSMakeRect (10, 10, 340, 100)];
  NSArray *labels = [NSArray arrayWithObjects: @"Overview", @"Activity", @"Settings", nil];
  NSEnumerator *enumerator = [labels objectEnumerator];
  NSString *label;
  NSBitmapImageRep *rep;
  CGFloat tabHeight = [[GSTheme theme] tabHeightForType: NSTopTabsBezelBorder];
  QuirkProbeInk accent, text;
  NSString *detail;

  while ((label = [enumerator nextObject]) != nil)
    {
      NSTabViewItem *item = [[NSTabViewItem alloc] initWithIdentifier: label];

      [item setLabel: label];
      [tabView addTabViewItem: item];
      RELEASE (item);
    }
  [[window contentView] addSubview: tabView];
  RELEASE (tabView);
  [window orderFront: nil];
  [window display];
  rep = QuirkProbeRender (tabView);
  [self saveWindow: window named: @"tabs"];
  [window orderOut: nil];

  accent = QuirkProbeMeasureIn (rep, QuirkProbeIsFocusBlue, NSMakeRect (0, 0, [rep pixelsWide], tabHeight));
  text = QuirkProbeMeasureIn (rep, QuirkProbeIsTextInk, NSMakeRect (0, 0, [rep pixelsWide], tabHeight));
  detail = [NSString stringWithFormat: @"accent %ldx%ld at x %ld in a %gpt strip; labels from x %ld",
    (long)accent.width, (long)accent.height, (long)accent.minX, tabHeight, (long)text.minX];
  /* One underline, 4px high, under the first tab only (it starts left of
     the first label and is far narrower than the strip). */
  if (accent.count > 0 && accent.height == 4 && accent.minX < text.minX
    && accent.width < [rep pixelsWide] / 2 && accent.count == (NSUInteger)(accent.width * accent.height))
    {
      [self pass: @"tab-view-flat" detail: detail];
    }
  else
    {
      [self fail: @"tab-view-flat" detail: detail];
    }
}

/* A toolbar the app gives no display mode starts icon-only, as GNOME header
   bars are; one the app sets keeps its mode, and a toolbar with the same
   identifier copies it. */
- (void) checkToolbarDisplayMode
{
  NSToolbar *fresh = AUTORELEASE ([[NSToolbar alloc] initWithIdentifier: @"QuirkProbeFresh"]);
  NSToolbar *chosen = AUTORELEASE ([[NSToolbar alloc] initWithIdentifier: @"QuirkProbeChosen"]);
  NSToolbar *sibling;
  NSString *detail;

  [chosen setDisplayMode: NSToolbarDisplayModeIconAndLabel];
  sibling = AUTORELEASE ([[NSToolbar alloc] initWithIdentifier: @"QuirkProbeChosen"]);
  detail = [NSString stringWithFormat: @"default %d, app's choice %d, same identifier %d (icon-only %d, icon and label %d)",
    (int)[fresh displayMode], (int)[chosen displayMode], (int)[sibling displayMode],
    (int)NSToolbarDisplayModeIconOnly, (int)NSToolbarDisplayModeIconAndLabel];
  if ([fresh displayMode] == NSToolbarDisplayModeIconOnly
    && [chosen displayMode] == NSToolbarDisplayModeIconAndLabel
    && [sibling displayMode] == NSToolbarDisplayModeIconAndLabel)
    {
      [self pass: @"toolbar-default-icon-only" detail: detail];
    }
  else
    {
      [self fail: @"toolbar-default-icon-only" detail: detail];
    }
}

/* With an application menu (the app has loose items such as Info), its ☰
   sits at the right end of the menu bar, and clicks there reach it. */
- (void) checkApplicationMenuPosition
{
  NSMenu *mainMenu = [NSApp mainMenu];
  NSMenu *appMenu = AUTORELEASE ([[NSMenu alloc] initWithTitle: [[NSProcessInfo processInfo] processName]]);
  NSMenuItem *appItem = AUTORELEASE ([[NSMenuItem alloc] initWithTitle: [[NSProcessInfo processInfo] processName]
                                                                  action: NULL
                                                           keyEquivalent: @""]);
  NSMenuView *menuView;
  NSRect appRect, fileRect;
  NSInteger hit;
  CGFloat submenuRight, itemRight;
  NSString *detail;

  if (NSInterfaceStyleForKey (@"NSMenuInterfaceStyle", nil) != NSWindows95InterfaceStyle)
    {
      [self skip: @"menubar-app-menu-at-end" detail: @"needs -NSMenuInterfaceStyle NSWindows95InterfaceStyle"];
      return;
    }
  [appMenu addItemWithTitle: @"Info" action: NULL keyEquivalent: @""];
  [appItem setSubmenu: appMenu];
  [mainMenu insertItem: appItem atIndex: 0];
  menuView = (NSMenuView *)QuirkProbeFindViewOfClass ([[_controlsWindow contentView] superview],
                                                      [NSMenuView class]);
  [menuView sizeToFit];
  appRect = [menuView rectOfItemAtIndex: 0];
  fileRect = [menuView rectOfItemAtIndex: 1];
  hit = [menuView indexOfItemAtPoint: NSMakePoint (NSMidX (appRect), NSMidY (appRect))];
  /* Its menu opens with right edges aligned. */
  submenuRight = [menuView locationForSubmenu: appMenu].x
    + NSWidth ([[[appMenu menuRepresentation] window] frame]);
  itemRight = [_controlsWindow convertBaseToScreen:
                 [menuView convertPoint: NSMakePoint (NSMaxX (appRect), 0) toView: nil]].x;
  [mainMenu removeItem: appItem];
  [menuView sizeToFit];

  detail = [NSString stringWithFormat: @"app menu at x %g-%g of %g, File at x %g, a click on the app menu hits item %ld, "
    @"its menu ends at screen x %g (the item at %g)",
    NSMinX (appRect), NSMaxX (appRect), NSWidth ([menuView bounds]), NSMinX (fileRect), (long)hit,
    submenuRight, itemRight];
  if (menuView == nil)
    {
      [self fail: @"menubar-app-menu-at-end" detail: @"no menu view in the window"];
    }
  else if (NSMaxX (appRect) > NSWidth ([menuView bounds]) - 20 && NSMinX (fileRect) < 20 && hit == 0
    && fabs (submenuRight - itemRight) < 1.0)
    {
      [self pass: @"menubar-app-menu-at-end" detail: detail];
    }
  else
    {
      [self fail: @"menubar-app-menu-at-end" detail: detail];
    }
}

/* A Cocoa-style main menu: an untitled first item holding the application
   menu. The theme names it after the app (so it becomes the ☰ menu instead
   of a blank item) and leaves out Hide, Hide Others and Show All. */
- (void) checkCocoaApplicationMenu
{
  NSMenu *original = RETAIN ([NSApp mainMenu]);
  NSMenu *cocoa = AUTORELEASE ([[NSMenu alloc] initWithTitle: @"Main"]);
  NSMenu *appMenu = AUTORELEASE ([[NSMenu alloc] initWithTitle: @"Apple"]);
  NSMenu *fileMenu = AUTORELEASE ([[NSMenu alloc] initWithTitle: @"File"]);
  NSString *name = [[NSProcessInfo processInfo] processName];
  NSMenuItem *first;
  NSMutableArray *titles = [NSMutableArray array];
  NSEnumerator *enumerator;
  NSMenuItem *item;
  BOOL hasHide = NO, hasAbout = NO;
  NSString *detail;

  [appMenu addItemWithTitle: @"About QuirkProbe" action: @selector(orderFrontStandardAboutPanel:) keyEquivalent: @""];
  [appMenu addItem: [NSMenuItem separatorItem]];
  [appMenu addItemWithTitle: @"Hide QuirkProbe" action: @selector(hide:) keyEquivalent: @"h"];
  [appMenu addItemWithTitle: @"Hide Others" action: @selector(hideOtherApplications:) keyEquivalent: @""];
  [appMenu addItemWithTitle: @"Show All" action: @selector(unhideAllApplications:) keyEquivalent: @""];
  [appMenu addItem: [NSMenuItem separatorItem]];
  [appMenu addItemWithTitle: @"Quit QuirkProbe" action: @selector(terminate:) keyEquivalent: @"q"];
  [fileMenu addItemWithTitle: @"Open" action: NULL keyEquivalent: @""];
  [cocoa setSubmenu: appMenu forItem: [cocoa addItemWithTitle: @"" action: NULL keyEquivalent: @""]];
  [cocoa setSubmenu: fileMenu forItem: [cocoa addItemWithTitle: @"File" action: NULL keyEquivalent: @""]];
  [NSApp setMainMenu: cocoa];

  enumerator = [[cocoa itemArray] objectEnumerator];
  while ((item = [enumerator nextObject]) != nil)
    {
      [titles addObject: [NSString stringWithFormat: @"\"%@\"", [item title]]];
    }
  first = (NSMenuItem *)[cocoa itemAtIndex: 0];
  enumerator = [[[first submenu] itemArray] objectEnumerator];
  while ((item = [enumerator nextObject]) != nil)
    {
      hasHide |= sel_isEqual ([item action], @selector(hide:));
      hasAbout |= sel_isEqual ([item action], @selector(orderFrontStandardAboutPanel:));
    }
  [NSApp setMainMenu: original];
  RELEASE (original);

  detail = [NSString stringWithFormat: @"menu bar %@; app menu %@ About, %@ Hide",
    [titles componentsJoinedByString: @" "], hasAbout ? @"has" : @"lacks", hasHide ? @"has" : @"no"];
  if (NSInterfaceStyleForKey (@"NSMenuInterfaceStyle", nil) != NSWindows95InterfaceStyle)
    {
      [self skip: @"menubar-cocoa-app-menu" detail: @"needs -NSMenuInterfaceStyle NSWindows95InterfaceStyle"];
    }
  else if ([titles count] == 2 && [[first title] isEqualToString: name] && hasAbout && hasHide == NO)
    {
      [self pass: @"menubar-cocoa-app-menu" detail: detail];
    }
  else
    {
      [self fail: @"menubar-cocoa-app-menu" detail: detail];
    }
}

/* Checks from putting Gorm through its paces: its inspectors use switches
   with the box to the right of the title, boxes whose title cell is an
   NSTextFieldCell, NSForms, grooved boxes, and a view-switcher toolbar. */
- (void) checkGormControls
{
  NSWindow *window = [self windowWithFrame: NSMakeRect (700, 500, 420, 120) title: @"QuirkProbe Gorm"];
  NSView *view = [window contentView];
  NSButton *trailing = AUTORELEASE ([[NSButton alloc] initWithFrame: NSMakeRect (10, 80, 140, 24)]);
  NSBox *box = AUTORELEASE ([[NSBox alloc] initWithFrame: NSMakeRect (160, 50, 120, 60)]);
  NSTextFieldCell *titleCell = AUTORELEASE ([[NSTextFieldCell alloc] initTextCell: @"Fy"]);
  NSTextField *reference = AUTORELEASE ([[NSTextField alloc] initWithFrame: NSMakeRect (300, 80, 100, 24)]);
  NSForm *form = AUTORELEASE ([[NSForm alloc] initWithFrame: NSMakeRect (10, 10, 260, 24)]);
  NSToolbar *switcher = AUTORELEASE ([[NSToolbar alloc] initWithIdentifier: @"QuirkProbeSwitcher"]);
  QuirkProbeSwitcherDelegate *switcherDelegate = AUTORELEASE ([QuirkProbeSwitcherDelegate new]);
  NSColor *highlight = [[NSColor controlHighlightColor] colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
  NSBitmapImageRep *rep;
  QuirkProbeInk text, indicator;
  NSArray *boxRows, *referenceRows;
  NSUInteger upright, flipped;
  NSRect entry;
  NSUInteger white;
  NSString *detail;

  [trailing setButtonType: NSSwitchButton];
  [trailing setTitle: @"Command"];
  [trailing setImagePosition: NSImageRight];
  [trailing setAlignment: NSRightTextAlignment];
  [view addSubview: trailing];

  [titleCell setFont: [NSFont systemFontOfSize: 12]];
  object_setIvar (box, class_getInstanceVariable ([NSBox class], "_cell"), RETAIN (titleCell));
  [box setBorderType: NSGrooveBorder];
  [box setTitlePosition: NSAtTop];
  [view addSubview: box];
  [reference setStringValue: @"Fy"];
  [reference setFont: [NSFont systemFontOfSize: 12]];
  [reference setBezeled: NO];
  [reference setDrawsBackground: NO];
  [view addSubview: reference];

  [form addEntry: @"Title:"];
  [form setBezeled: YES];
  [view addSubview: form];
  [window orderFront: nil];
  [window display];
  [self saveWindow: window named: @"gorm-controls"];

  /* Switch with its box on the right. */
  rep = QuirkProbeRender (trailing);
  text = QuirkProbeMeasure (rep, QuirkProbeIsTextInk);
  indicator = QuirkProbeMeasureIn (rep, QuirkProbeIsNotWhite,
                                   NSMakeRect (text.minX + text.width + 1, 0, [rep pixelsWide], [rep pixelsHigh]));
  detail = [NSString stringWithFormat: @"title ink x %ld-%ld, box from x %ld",
    (long)text.minX, (long)(text.minX + text.width), (long)indicator.minX];
  if (text.count > 0 && indicator.count > 0 && indicator.minX > text.minX + text.width)
    [self pass: @"switch-box-on-right" detail: detail];
  else
    [self fail: @"switch-box-on-right" detail: detail];

  /* Box title upright: its ink profile matches a label's, not the label's
     turned upside down. */
  rep = QuirkProbeRender (box);
  boxRows = QuirkProbeInkRows (rep, NSMakeRect (0, 0, [rep pixelsWide], 20));
  rep = QuirkProbeRender (reference);
  referenceRows = QuirkProbeInkRows (rep, NSMakeRect (0, 0, [rep pixelsWide], [rep pixelsHigh]));
  upright = QuirkProbeProfileDistance (boxRows, referenceRows, NO);
  flipped = QuirkProbeProfileDistance (boxRows, referenceRows, YES);
  detail = [NSString stringWithFormat: @"%lu rows of ink; differs from a label by %lu upright, %lu upside down",
    (unsigned long)[boxRows count], (unsigned long)upright, (unsigned long)flipped];
  if ([boxRows count] > 0 && upright < flipped)
    [self pass: @"box-title-upright" detail: detail];
  else
    [self fail: @"box-title-upright" detail: detail];

  /* Bevel highlights are neutral, not the accent colour. */
  detail = [NSString stringWithFormat: @"controlHighlightColor %.2f %.2f %.2f",
    [highlight redComponent], [highlight greenComponent], [highlight blueComponent]];
  if (fabs ([highlight blueComponent] - [highlight redComponent]) < 0.1)
    [self pass: @"bevel-highlight-neutral" detail: detail];
  else
    [self fail: @"bevel-highlight-neutral" detail: detail];

  /* A form's entry is an Adwaita entry, not a white box. */
  rep = QuirkProbeRender (form);
  entry = NSMakeRect ([[form cellAtIndex: 0] titleWidth] + 10, 8, 60, 8);
  white = QuirkProbeMeasureIn (rep, QuirkProbeIsWhite, entry).count;
  detail = [NSString stringWithFormat: @"%lu of %lu entry pixels white",
    (unsigned long)white, (unsigned long)QuirkProbeMeasureIn (rep, QuirkProbeIsAnyPixel, entry).count];
  if (white == 0)
    [self pass: @"form-entry-adwaita" detail: detail];
  else
    [self fail: @"form-entry-adwaita" detail: detail];
  [window orderOut: nil];

  /* A view switcher keeps its labels. */
  [switcher setDelegate: switcherDelegate];
  detail = [NSString stringWithFormat: @"display mode %d (icon and label %d)",
    (int)[switcher displayMode], (int)NSToolbarDisplayModeIconAndLabel];
  if ([switcher displayMode] == NSToolbarDisplayModeIconAndLabel)
    [self pass: @"toolbar-view-switcher-labels" detail: detail];
  else
    [self fail: @"toolbar-view-switcher-labels" detail: detail];
  [switcher setDelegate: nil];
}

/* An app built in code (no main nib) gets GNOME's metrics: the interface
   font at GNOME's size, not GNUstep's 12pt, and bold button titles. Apps
   with a main Gorm or nib file get GNUstep's metrics instead (compact),
   and -GnomeThemeMetrics compact|gnome overrides either way. */
- (void) checkMetricsMode
{
  NSString *choice = [[NSUserDefaults standardUserDefaults] stringForKey: @"GnomeThemeMetrics"];
  CGFloat size = [[NSFont systemFontOfSize: 0] pointSize];
  BOOL compact = [choice isEqualToString: @"compact"];
  NSString *detail = [NSString stringWithFormat: @"system font %gpt (%@)",
    size, choice != nil ? choice : @"automatic, no main nib"];

  if ((compact && fabs (size - 12.0) < 0.5) || (compact == NO && size > 13.0))
    {
      [self pass: @"metrics-mode" detail: detail];
    }
  else
    {
      [self fail: @"metrics-mode" detail: detail];
    }
}

/* What the primary menu showed, seen from inside its tracking loop. */
static NSMutableArray *QuirkProbePrimaryTitles = nil;
/* Set when the Escape check had to close the menu with a click. */
static BOOL QuirkProbeEscapeNeededClick = NO;
static NSRect QuirkProbePrimaryFrame;

static NSView *
QuirkProbePrimaryButtonIn (NSView *view)
{
  return QuirkProbeFindViewOfClass (view, NSClassFromString (@"GnomeThemePrimaryMenuButton"));
}

/* Fires while the ☰'s menu is tracking: presses Escape. */
- (void) pressEscape: (NSTimer *)timer
{
  NSString *escape = [NSString stringWithFormat: @"%C", (unichar)0x1b];

  [NSApp postEvent: [NSEvent keyEventWithType: NSKeyDown
                                     location: NSZeroPoint
                                modifierFlags: 0
                                    timestamp: 0
                                 windowNumber: [_controlsWindow windowNumber]
                                      context: nil
                                   characters: escape
                  charactersIgnoringModifiers: escape
                                    isARepeat: NO
                                      keyCode: 9]
           atStart: NO];
}

/* Fires if Escape didn't close the menu: close it with a click. */
- (void) closeMenuAfterEscape: (NSTimer *)timer
{
  NSEvent *up = [NSEvent mouseEventWithType: NSLeftMouseUp location: NSMakePoint (-50, -50) modifierFlags: 0
                                  timestamp: 0 windowNumber: 0 context: nil eventNumber: 0 clickCount: 1 pressure: 0];

  QuirkProbeEscapeNeededClick = YES;
  [NSApp postEvent: up atStart: NO];
}

/* Fires while the ☰'s menu is tracking: note the vertical menu that's
   showing, then close it with a click outside. */
- (void) inspectPrimaryMenu: (NSTimer *)timer
{
  NSEnumerator *enumerator = [[NSApp windows] objectEnumerator];
  NSWindow *window;
  NSEvent *up, *down;

  while ((window = [enumerator nextObject]) != nil)
    {
      NSMenuView *menuView = (NSMenuView *)QuirkProbeFindViewOfClass ([window contentView], [NSMenuView class]);

      if ([window isVisible] && menuView != nil && [menuView isHorizontal] == NO)
        {
          NSEnumerator *items = [[[menuView menu] itemArray] objectEnumerator];
          NSMenuItem *item;

          QuirkProbePrimaryFrame = [window frame];
          [self saveWindow: window named: @"primary-menu"];
          while ((item = [items nextObject]) != nil)
            {
              [QuirkProbePrimaryTitles addObject: [item isSeparatorItem] ? @"--" : [item title]];
            }
        }
    }
  up = [NSEvent mouseEventWithType: NSLeftMouseUp location: NSMakePoint (-50, -50) modifierFlags: 0
                         timestamp: 0 windowNumber: 0 context: nil eventNumber: 0 clickCount: 1 pressure: 0];
  down = [NSEvent mouseEventWithType: NSLeftMouseDown location: NSMakePoint (-50, -50) modifierFlags: 0
                           timestamp: 0 windowNumber: 0 context: nil eventNumber: 0 clickCount: 1 pressure: 1];
  [NSApp postEvent: up atStart: NO];
  [NSApp postEvent: down atStart: NO];
  [NSApp postEvent: up atStart: NO];
}

/* With -GnomeThemeMenuStyle primary: a window without a toolbar shows a
   slim bar holding ☰; a window with one shows ☰ at the toolbar's end and no
   menu bar; clicking ☰ shows the main menu vertically under it. */
- (void) checkPrimaryMenu
{
  NSView *barButton;
  NSString *detail;
  NSRect buttonInWindow;
  NSEvent *click;

  if ([[[NSUserDefaults standardUserDefaults] stringForKey: @"GnomeThemeMenuStyle"] isEqualToString: @"primary"] == NO)
    {
      [self skip: @"primary-menu" detail: @"needs -GnomeThemeMenuStyle primary"];
      return;
    }

  if (QuirkProbeDrawsDecorations ())
    {
      [self checkPrimaryMenuInHeaderBar];
    }
  else
    {
      [self checkPrimaryMenuInMenuBar];
    }

  /* Open it, with an application menu and an Edit menu added: the click's
     tracking loop runs until -inspectPrimaryMenu: closes the menu. */
  {
    NSMenu *mainMenu = [NSApp mainMenu];
    NSString *name = [[NSProcessInfo processInfo] processName];
    NSMenu *appMenu = AUTORELEASE ([[NSMenu alloc] initWithTitle: name]);
    NSMenu *editMenu = AUTORELEASE ([[NSMenu alloc] initWithTitle: @"Edit"]);
    NSMenuItem *appItem = AUTORELEASE ([[NSMenuItem alloc] initWithTitle: name action: NULL keyEquivalent: @""]);
    NSMenuItem *editItem = AUTORELEASE ([[NSMenuItem alloc] initWithTitle: @"Edit" action: NULL keyEquivalent: @""]);

    [appMenu addItemWithTitle: @"Preferences…" action: NULL keyEquivalent: @","];
    [appMenu addItemWithTitle: @"About QuirkProbe" action: @selector(orderFrontStandardAboutPanel:) keyEquivalent: @""];
    [editMenu addItemWithTitle: @"Copy" action: @selector(copy:) keyEquivalent: @"c"];
    [appItem setSubmenu: appMenu];
    [editItem setSubmenu: editMenu];
    [mainMenu insertItem: appItem atIndex: 0];
    [mainMenu addItem: editItem];
    _primaryExtraItems = [[NSArray alloc] initWithObjects: appItem, editItem, nil];
  }
  ASSIGN (QuirkProbePrimaryTitles, [NSMutableArray array]);
  /* Changing the main menu gives the window a new menu view and ☰. */
  barButton = QuirkProbePrimaryButtonIn ([[_controlsWindow contentView] superview]);
  buttonInWindow = [barButton convertRect: [barButton bounds] toView: nil];
  click = [NSEvent mouseEventWithType: NSLeftMouseDown
                             location: NSMakePoint (NSMaxX (buttonInWindow) - 23, NSMidY (buttonInWindow))
                        modifierFlags: 0
                            timestamp: 0
                         windowNumber: [_controlsWindow windowNumber]
                              context: nil
                          eventNumber: 0
                           clickCount: 1
                             pressure: 1.0];
  /* A click: the menu opens on the release and stays open. */
  [NSApp postEvent: [NSEvent mouseEventWithType: NSLeftMouseUp
                                       location: [click locationInWindow]
                                  modifierFlags: 0
                                      timestamp: 0
                                   windowNumber: [_controlsWindow windowNumber]
                                        context: nil
                                    eventNumber: 0
                                     clickCount: 1
                                       pressure: 0.0]
           atStart: NO];
  [self after: 0.3 perform: @selector(inspectPrimaryMenu:) mode: NSEventTrackingRunLoopMode];
  [barButton mouseDown: click];
  {
    NSEnumerator *extras = [_primaryExtraItems objectEnumerator];
    NSMenuItem *extra;

    while ((extra = [extras nextObject]) != nil)
      {
        [[NSApp mainMenu] removeItem: extra];
      }
    DESTROY (_primaryExtraItems);
  }

  detail = [NSString stringWithFormat: @"menu %@ at %@, the button's right edge at %g",
    [QuirkProbePrimaryTitles componentsJoinedByString: @" | "], NSStringFromRect (QuirkProbePrimaryFrame),
    [_controlsWindow convertBaseToScreen: NSMakePoint (NSMaxX (buttonInWindow) - 6, 0)].x];
  /* Escape closes it. */
  {
    NSTimer *fallback;

    barButton = QuirkProbePrimaryButtonIn ([[_controlsWindow contentView] superview]);
    [NSApp postEvent: [NSEvent mouseEventWithType: NSLeftMouseUp
                                         location: [click locationInWindow]
                                    modifierFlags: 0
                                        timestamp: 0
                                     windowNumber: [_controlsWindow windowNumber]
                                          context: nil
                                      eventNumber: 0
                                       clickCount: 1
                                         pressure: 0.0]
             atStart: NO];
    [self after: 0.3 perform: @selector(pressEscape:) mode: NSEventTrackingRunLoopMode];
    fallback = [NSTimer timerWithTimeInterval: 1.5 target: self selector: @selector(closeMenuAfterEscape:)
                                     userInfo: nil repeats: NO];
    [[NSRunLoop currentRunLoop] addTimer: fallback forMode: NSEventTrackingRunLoopMode];
    [barButton mouseDown: click];
    [fallback invalidate];
    if (QuirkProbeEscapeNeededClick == NO)
      [self pass: @"primary-menu-escape" detail: @"Escape closed the menu"];
    else
      [self fail: @"primary-menu-escape" detail: @"the menu stayed open after Escape"];
  }

  /* The app's menus in order, then its application menu's items. */
  if ([[QuirkProbePrimaryTitles componentsJoinedByString: @" | "]
        isEqualToString: @"File | Edit | -- | Preferences… | About QuirkProbe"]
    && fabs (NSMaxX (QuirkProbePrimaryFrame) - [_controlsWindow convertBaseToScreen: NSMakePoint (NSMaxX (buttonInWindow) - 6, 0)].x) < 1.0)
    [self pass: @"primary-menu-opens" detail: detail];
  else
    [self fail: @"primary-menu-opens" detail: detail];
}

/* Without the header bar, the ☰ is in a slim bar, or at the toolbar's end
   when the window shows one. */
- (void) checkPrimaryMenuInMenuBar
{
  NSView *controlsFrame = [[_controlsWindow contentView] superview];
  NSView *toolbarFrame = [[_toolbarWindow contentView] superview];
  NSMenuView *controlsBar = (NSMenuView *)QuirkProbeFindViewOfClass (controlsFrame, [NSMenuView class]);
  NSMenuView *toolbarBar = (NSMenuView *)QuirkProbeFindViewOfClass (toolbarFrame, [NSMenuView class]);
  NSView *barButton = QuirkProbePrimaryButtonIn (controlsBar);
  NSView *toolbarView = QuirkProbeFindViewOfClass (toolbarFrame, NSClassFromString (@"GSToolbarView"));
  NSView *toolbarButton = QuirkProbePrimaryButtonIn (toolbarFrame);
  NSString *detail;

  detail = [NSString stringWithFormat: @"bar %gpt high with %@; toolbar window: bar %gpt, ☰ %@ beside a toolbar ending at %g",
    NSHeight ([controlsBar frame]), barButton != nil ? @"☰" : @"no ☰",
    NSHeight ([toolbarBar frame]), NSStringFromRect ([toolbarButton frame]), NSMaxX ([toolbarView frame])];
  if (barButton != nil && NSHeight ([controlsBar frame]) >= 34 && ([toolbarBar superview] == nil || NSHeight ([toolbarBar frame]) == 0)
    && toolbarButton != nil && NSMinX ([toolbarButton frame]) == NSMaxX ([toolbarView frame])
    && NSMaxX ([toolbarButton frame]) == NSMaxX ([toolbarFrame bounds]))
    [self pass: @"primary-menu-placement" detail: detail];
  else
    [self fail: @"primary-menu-placement" detail: detail];

  /* Hiding the toolbar moves ☰ to a bar; showing it again moves it back.
     The content view keeps meeting the bar or toolbar with no gap. */
  {
    NSToolbar *toolbar = [_toolbarWindow toolbar];
    NSView *content = [_toolbarWindow contentView];
    NSMenuView *bar;
    CGFloat hiddenBar, hiddenGap, shownGap;

    [toolbar setVisible: NO];
    bar = (NSMenuView *)QuirkProbeFindViewOfClass (toolbarFrame, [NSMenuView class]);
    hiddenBar = NSHeight ([bar frame]);
    hiddenGap = NSMinY ([bar frame]) - NSMaxY ([content frame]);
    [toolbar setVisible: YES];
    toolbarView = QuirkProbeFindViewOfClass (toolbarFrame, NSClassFromString (@"GSToolbarView"));
    toolbarButton = QuirkProbePrimaryButtonIn (toolbarFrame);
    shownGap = NSMinY ([toolbarView frame]) - NSMaxY ([content frame]);
    detail = [NSString stringWithFormat: @"toolbar hidden: bar %gpt, %gpt above the content; shown: toolbar %gpt above it, ☰ %@",
      hiddenBar, hiddenGap, shownGap, NSStringFromRect ([toolbarButton frame])];
    if (hiddenBar >= 34 && QuirkProbePrimaryButtonIn (bar) != nil && fabs (hiddenGap) <= 1 && fabs (shownGap) <= 1
      && [toolbarButton window] == _toolbarWindow && NSMinX ([toolbarButton frame]) == NSMaxX ([toolbarView frame]))
      [self pass: @"primary-menu-toolbar-toggle" detail: detail];
    else
      [self fail: @"primary-menu-toolbar-toggle" detail: detail];
  }
}

/* With the header bar, the ☰ is in it: at the bar's end, or 6pt before the
   window buttons (the ☰ view keeps that margin at its right). There's no
   menu bar row, and the toolbar isn't narrowed for it. */
- (void) checkPrimaryMenuInHeaderBar
{
  NSView *controlsFrame = [[_controlsWindow contentView] superview];
  NSView *headerFrame = [[_headerWindow contentView] superview];
  NSView *toolbarFrame = [[_toolbarWindow contentView] superview];
  NSView *controlsButton = QuirkProbePrimaryButtonIn (controlsFrame);
  NSView *headerButton = QuirkProbePrimaryButtonIn (headerFrame);
  NSView *toolbarButton = QuirkProbePrimaryButtonIn (toolbarFrame);
  NSArray *windowButtons = QuirkProbeWindowButtons (headerFrame);
  NSMenuView *bar = (NSMenuView *)QuirkProbeFindViewOfClass (controlsFrame, [NSMenuView class]);
  NSView *toolbarView = QuirkProbeFindViewOfClass (toolbarFrame, NSClassFromString (@"GSToolbarView"));
  NSView *content = [_toolbarWindow contentView];
  NSToolbar *toolbar = [_toolbarWindow toolbar];
  CGFloat hiddenGap, shownGap;
  NSString *detail;

  detail = [NSString stringWithFormat: @"☰ %@ in a %gpt-wide frame, %gpt from the top; ☰ %@ before buttons from %g; menu bar %gpt; toolbar to %g, content to %g",
    NSStringFromRect ([controlsButton frame]), NSWidth ([controlsFrame bounds]),
    QuirkProbeTopGap (controlsFrame, [controlsButton frame]), NSStringFromRect ([headerButton frame]),
    [windowButtons count] > 0 ? NSMinX ([[windowButtons objectAtIndex: 0] frame]) : -1.0,
    NSHeight ([bar frame]), NSMaxX ([toolbarView frame]), NSMaxX ([content frame])];
  if ([controlsButton superview] == controlsFrame && NSMaxX ([controlsButton frame]) == NSMaxX ([controlsFrame bounds])
    && QuirkProbeTopGap (controlsFrame, [controlsButton frame]) == 0 && NSHeight ([controlsButton frame]) == 46
    && [headerButton superview] == headerFrame && [windowButtons count] > 0
    && NSMaxX ([headerButton frame]) == NSMinX ([[windowButtons objectAtIndex: 0] frame])
    && (bar == nil || [bar superview] == nil || NSHeight ([bar frame]) == 0)
    && [toolbarButton superview] == toolbarFrame && NSMaxX ([toolbarView frame]) == NSMaxX ([content frame]))
    [self pass: @"primary-menu-placement" detail: detail];
  else
    [self fail: @"primary-menu-placement" detail: detail];

  /* Hiding the toolbar leaves no bar: the content meets the header bar. */
  [toolbar setVisible: NO];
  hiddenGap = QuirkProbeTopGap (toolbarFrame, [content frame]);
  [toolbar setVisible: YES];
  toolbarView = QuirkProbeFindViewOfClass (toolbarFrame, NSClassFromString (@"GSToolbarView"));
  shownGap = QuirkProbeTopGap (toolbarFrame, [toolbarView frame]);
  detail = [NSString stringWithFormat: @"toolbar hidden: content %gpt from the top; shown: toolbar %gpt from the top, %gpt above the content",
    hiddenGap, shownGap, NSMinY ([toolbarView frame]) - NSMaxY ([content frame])];
  if (hiddenGap == 46 && shownGap == 46 && fabs (NSMinY ([toolbarView frame]) - NSMaxY ([content frame])) <= 1
    && [QuirkProbePrimaryButtonIn (toolbarFrame) superview] == toolbarFrame)
    [self pass: @"primary-menu-toolbar-toggle" detail: detail];
  else
    [self fail: @"primary-menu-toolbar-toggle" detail: detail];
}

/* The header bar the theme draws when GNUstep draws the decorations,
   measured against libadwaita 1.7 (Reference/HeaderBar). */
- (void) checkHeaderBar
{
  NSView *frameView = [[_headerWindow contentView] superview];
  NSRect bounds = [frameView bounds];
  NSArray *buttons = QuirkProbeWindowButtons (frameView);
  NSButton *closeButton = [buttons lastObject];
  NSString *detail;
  NSRect titleInk = NSZeroRect;
  NSUInteger barBackground = 750;
  /* Set by run-quirk-probe.sh for QUIRK_PROBE_STYLE=high-contrast. */
  BOOL highContrast = [[NSUserDefaults standardUserDefaults] boolForKey: @"ProbeHighContrast"];

  if (QuirkProbeDrawsDecorations () == NO)
    {
      [self skip: @"header-bar" detail: @"needs -GSX11HandlesWindowDecorations NO"];
      return;
    }

  /* A 46pt bar; 34pt buttons 6pt from the top and the end, 3pt apart, in
     button-layout's order (appmenu:minimize,maximize,close here). */
  {
    NSMutableArray *parts = [NSMutableArray array];
    NSEnumerator *enumerator = [[frameView subviews] objectEnumerator];
    NSView *subview;
    CGFloat below = NSHeight (bounds);
    BOOL ok = [frameView isKindOfClass: NSClassFromString (@"GnomeThemeHeaderBarDecorationView")] && [buttons count] == 3;
    NSUInteger i;

    while ((subview = [enumerator nextObject]) != nil)
      {
        if ([buttons containsObject: subview] == NO && subview != QuirkProbePrimaryButtonIn (frameView))
          {
            below = MIN (below, QuirkProbeTopGap (frameView, [subview frame]));
          }
      }
    for (i = 0; i < [buttons count]; i++)
      {
        NSButton *button = [buttons objectAtIndex: i];
        NSRect frame = [button frame];
        NSInteger expected[] = { NSWindowMiniaturizeButton, NSWindowZoomButton, NSWindowCloseButton };

        [parts addObject: [NSString stringWithFormat: @"%ld at %@", (long)[button tag], NSStringFromRect (frame)]];
        ok = ok && i < 3 && [button tag] == expected[i] && NSWidth (frame) == 34 && NSHeight (frame) == 34
          && QuirkProbeTopGap (frameView, frame) == 6
          && (i == 0 || NSMinX (frame) - NSMaxX ([[buttons objectAtIndex: i - 1] frame]) == 3);
      }
    ok = ok && NSMaxX ([closeButton frame]) == NSMaxX (bounds) - 6 && below == 46;
    detail = [NSString stringWithFormat: @"%@ in %@; content %gpt from the top; buttons %@",
      NSStringFromClass ([frameView class]), NSStringFromRect (bounds), below,
      [parts componentsJoinedByString: @", "]];
    if (ok)
      [self pass: @"header-bar-layout" detail: detail];
    else
      [self fail: @"header-bar-layout" detail: detail];
  }

  /* Rendered: the bold title centred on the window (or, when that would
     reach them, 6pt clear of the controls at the end, as GTK's centre box
     shifts it) with its ink 17px from the top (as libadwaita's), and a
     circle 10% of the text colour behind the buttons. */
  {
    NSBitmapImageRep *rep;
    QuirkProbeInk title, circle, background, ring;
    NSRect closeFrame = [closeButton frame];
    NSView *menuButton = QuirkProbePrimaryButtonIn (frameView);
    CGFloat circleY = QuirkProbeTopGap (frameView, closeFrame) + 17;
    CGFloat centre, expected, end;
    long circleContrast, ringContrast;

    /* Renders come from the backing store: draw the focus change first. */
    [_headerWindow makeKeyWindow];
    [_headerWindow displayIfNeeded];
    rep = QuirkProbeRender (frameView);
    barBackground = QuirkProbeMeasureIn (rep, QuirkProbeIsAnyPixel, NSMakeRect (20, 4, 4, 4)).darkest;
    QuirkProbeInkBackground = barBackground;
    /* Inside the border, up to the buttons, or the ☰ before them in the
       primary menu's run. */
    title = QuirkProbeMeasureIn (rep, QuirkProbeIsInk,
                                 NSMakeRect (1, 1, NSMinX (menuButton != nil ? [menuButton frame]
                                                           : [[buttons objectAtIndex: 0] frame]) - 1, 44));
    titleInk = NSMakeRect (title.minX, title.minY, title.width, title.height);
    centre = title.minX + title.width / 2.0;
    end = NSMinX (menuButton != nil ? [menuButton frame] : [[buttons objectAtIndex: 0] frame]) - 6;
    expected = MIN (NSWidth (bounds) / 2.0, end - title.width / 2.0);
    circle = QuirkProbeMeasureIn (rep, QuirkProbeIsAnyPixel, NSMakeRect (NSMinX (closeFrame) + 6, circleY - 1, 2, 3));
    background = QuirkProbeMeasureIn (rep, QuirkProbeIsAnyPixel, NSMakeRect (NSMinX (closeFrame) - 2, circleY - 1, 1, 3));
    /* The circle's left edge: its ring in high contrast. */
    ring = QuirkProbeMeasureIn (rep, QuirkProbeIsAnyPixel, NSMakeRect (NSMinX (closeFrame) + 5, circleY - 1, 1, 3));
    circleContrast = labs ((long)circle.darkest - (long)background.darkest);
    ringContrast = labs ((long)ring.darkest - (long)background.darkest);
    detail = [NSString stringWithFormat: @"title ink %ldx%ld at (%ld, %ld), centre %g (expected %g); circle %lu, its edge %lu, on %lu%@",
      (long)title.width, (long)title.height, (long)title.minX, (long)title.minY, centre, expected,
      (unsigned long)circle.darkest, (unsigned long)ring.darkest, (unsigned long)background.darkest,
      highContrast ? @" (high contrast: a ring)" : @""];
    if (title.count > 0 && fabs (centre - expected) <= 3 && title.minY >= 16 && title.minY <= 18
      && title.height >= 10 && title.height <= 14
      && circleContrast > 30 && circleContrast < 110
      && (highContrast == NO || ringContrast > circleContrast + 60))
      [self pass: @"header-bar-render" detail: detail];
    else
      [self fail: @"header-bar-render" detail: detail];
  }

  /* Another window key: the title dims, as GTK's backdrop state. */
  {
    NSUInteger focused = QuirkProbeContrast (QuirkProbeMeasureIn (QuirkProbeRender (frameView), QuirkProbeIsAnyPixel, titleInk),
                                             barBackground);
    NSUInteger dimmed;

    [_controlsWindow makeKeyWindow];
    [_headerWindow displayIfNeeded];
    dimmed = QuirkProbeContrast (QuirkProbeMeasureIn (QuirkProbeRender (frameView), QuirkProbeIsAnyPixel, titleInk),
                                 barBackground);
    detail = [NSString stringWithFormat: @"title's contrast with the bar %lu focused, %lu not", (unsigned long)focused, (unsigned long)dimmed];
    if (focused >= 450 && dimmed + 150 <= focused)
      [self pass: @"header-bar-backdrop" detail: detail];
    else
      [self fail: @"header-bar-backdrop" detail: detail];
  }

  /* Edges resize: the frame view takes clicks there, over the content.
     A window that can't be resized leaves them to the content. */
  {
    NSView *controlsFrame = [[_controlsWindow contentView] superview];
    CGFloat midY = NSMidY (bounds) - 20;
    BOOL edges = [frameView hitTest: NSMakePoint (2, midY)] == frameView
      && [frameView hitTest: NSMakePoint (NSMaxX (bounds) - 2, midY)] == frameView
      && [frameView hitTest: NSMakePoint (NSMidX (bounds), 2)] == frameView
      && [frameView hitTest: NSMakePoint (3, 3)] == frameView;
    NSView *inside = [frameView hitTest: NSMakePoint (12, midY)];
    NSView *fixed = [controlsFrame hitTest: NSMakePoint (2, 100)];

    NSCursor *leftCursor, *cornerCursor, *insideCursor;

    /* The cursor shows the resize direction. */
    [_headerWindow makeKeyWindow];
    [_headerWindow resetCursorRects];
    QuirkProbeMoveMouseForCursor (_headerWindow, NSMakePoint (NSMidX (bounds), NSMidY (bounds) - 20));
    QuirkProbeMoveMouseForCursor (_headerWindow, NSMakePoint (2, midY));
    leftCursor = [NSCursor currentCursor];
    QuirkProbeMoveMouseForCursor (_headerWindow, NSMakePoint (3, 3));
    cornerCursor = [NSCursor currentCursor];
    QuirkProbeMoveMouseForCursor (_headerWindow, NSMakePoint (NSMidX (bounds), NSMidY (bounds) - 20));
    insideCursor = [NSCursor currentCursor];
    [_controlsWindow makeKeyWindow];

    detail = [NSString stringWithFormat: @"edges %@; 12pt in: %@; unresizable window's edge: %@; cursors: left edge %@, corner %@, inside %@",
      edges ? @"taken" : @"not taken", NSStringFromClass ([inside class]), NSStringFromClass ([fixed class]),
      leftCursor == [NSCursor resizeLeftRightCursor] ? @"left-right" : @"other",
      (cornerCursor != leftCursor && cornerCursor != [NSCursor resizeUpDownCursor] && cornerCursor != insideCursor) ? @"diagonal" : @"other",
      insideCursor == [NSCursor arrowCursor] ? @"arrow" : @"other"];
    if (edges && inside != frameView && fixed != controlsFrame
      && leftCursor == [NSCursor resizeLeftRightCursor] && cornerCursor != leftCursor
      && cornerCursor != insideCursor && insideCursor != leftCursor)
      [self pass: @"header-bar-resize-edges" detail: detail];
    else
      [self fail: @"header-bar-resize-edges" detail: detail];
  }

  /* Double-clicking the bar maximises (GNOME's default action); again
     goes back to the frame before. */
  {
    NSRect before = [_headerWindow frame];
    NSRect maximised;
    BOOL zoomed;

    QuirkProbeClick (_headerWindow, NSMakePoint (40, NSHeight ([frameView bounds]) - 20), 2);
    maximised = [_headerWindow frame];
    zoomed = [_headerWindow isZoomed];
    QuirkProbeClick (_headerWindow, NSMakePoint (40, NSHeight ([frameView bounds]) - 20), 2);
    detail = [NSString stringWithFormat: @"%@, then %@ (%@), then %@", NSStringFromRect (before),
      NSStringFromRect (maximised), zoomed ? @"zoomed" : @"not zoomed", NSStringFromRect ([_headerWindow frame])];
    if (zoomed && NSEqualRects (maximised, before) == NO && NSEqualRects ([_headerWindow frame], before))
      [self pass: @"header-bar-double-click" detail: detail];
    else
      [self fail: @"header-bar-double-click" detail: detail];
  }

  /* Right to left (as GTK in Arabic or Hebrew): the buttons at the end go
     to the left, close outermost, 6pt from the edge; the ☰ 6pt to their
     right. Switched through a volatile domain, so nothing is saved. */
  {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *searchList = AUTORELEASE ([[defaults searchList] mutableCopy]);
    NSArray *mirrored;
    NSView *menuButton;
    NSMutableArray *parts = [NSMutableArray array];
    BOOL ok;
    NSUInteger i;

    [defaults setVolatileDomain: [NSDictionary dictionaryWithObject: @"YES" forKey: @"NSForceRightToLeftWritingDirection"]
                        forName: @"QuirkProbeRightToLeft"];
    [searchList insertObject: @"QuirkProbeRightToLeft" atIndex: 0];
    [defaults setSearchList: searchList];
    [frameView performSelector: @selector(updateRects)];
    mirrored = QuirkProbeWindowButtons (frameView);
    menuButton = QuirkProbePrimaryButtonIn (frameView);
    for (i = 0; i < [mirrored count]; i++)
      {
        [parts addObject: [NSString stringWithFormat: @"%ld at %g", (long)[[mirrored objectAtIndex: i] tag],
          NSMinX ([[mirrored objectAtIndex: i] frame])]];
      }
    if (menuButton != nil)
      {
        [parts addObject: [NSString stringWithFormat: @"☰ view at %g", NSMinX ([menuButton frame])]];
      }
    ok = [mirrored count] == 3
      && [[mirrored objectAtIndex: 0] tag] == NSWindowCloseButton && NSMinX ([[mirrored objectAtIndex: 0] frame]) == 6
      && [[mirrored objectAtIndex: 1] tag] == NSWindowZoomButton && NSMinX ([[mirrored objectAtIndex: 1] frame]) == 43
      && [[mirrored objectAtIndex: 2] tag] == NSWindowMiniaturizeButton && NSMinX ([[mirrored objectAtIndex: 2] frame]) == 80
      && (menuButton == nil || NSMinX ([menuButton frame]) == 120);

    [searchList removeObject: @"QuirkProbeRightToLeft"];
    [defaults setSearchList: searchList];
    [defaults removeVolatileDomainForName: @"QuirkProbeRightToLeft"];
    [frameView performSelector: @selector(updateRects)];

    detail = [parts componentsJoinedByString: @", "];
    if (ok)
      [self pass: @"header-bar-rtl" detail: detail];
    else
      [self fail: @"header-bar-rtl" detail: detail];
  }

  /* A right-click on the bar opens the window menu (GNOME's default
     action-right-click-titlebar), which stays open after the release. */
  {
    NSPoint inBar = NSMakePoint (40, NSHeight ([frameView bounds]) - 20);
    NSString *titles;

    ASSIGN (QuirkProbePrimaryTitles, [NSMutableArray array]);
    [NSApp postEvent: [NSEvent mouseEventWithType: NSRightMouseUp location: inBar modifierFlags: 0 timestamp: 0
                                     windowNumber: [_headerWindow windowNumber] context: nil eventNumber: 0
                                       clickCount: 1 pressure: 0.0]
             atStart: NO];
    [self after: 0.3 perform: @selector(inspectPrimaryMenu:) mode: NSEventTrackingRunLoopMode];
    [NSApp sendEvent: [NSEvent mouseEventWithType: NSRightMouseDown location: inBar modifierFlags: 0 timestamp: 0
                                     windowNumber: [_headerWindow windowNumber] context: nil eventNumber: 0
                                       clickCount: 1 pressure: 1.0]];
    titles = [QuirkProbePrimaryTitles componentsJoinedByString: @" | "];
    if ([titles isEqualToString: @"Hide | Maximize | -- | Always on Top | -- | Close"])
      [self pass: @"header-bar-window-menu" detail: titles];
    else
      [self fail: @"header-bar-window-menu" detail: [titles length] > 0 ? titles : @"no menu open 0.3s after the click"];
  }

  /* Other kinds of window: where the content starts and which buttons
     show. Panels (utility ones too) get the bar, as GNOME's dialogs do;
     a window with buttons and no title gets the bar without one; without
     title or buttons only the border stays; fullscreen has neither. */
  {
    struct { const char *name; BOOL panel; NSUInteger style; CGFloat top; NSUInteger buttons; } kinds[] = {
      { "panel", YES, NSTitledWindowMask | NSClosableWindowMask, 46, 1 },
      { "utility", YES, NSTitledWindowMask | NSClosableWindowMask | NSUtilityWindowMask, 46, 1 },
      { "untitled", NO, NSClosableWindowMask | NSResizableWindowMask, 46, 2 },
      { "resizable", NO, NSResizableWindowMask, 1, 0 },
      { "borderless", NO, NSBorderlessWindowMask, 0, 0 },
      { "fullscreen", NO, NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask | NSFullScreenWindowMask, 0, 0 }
    };
    NSMutableArray *parts = [NSMutableArray array];
    BOOL ok = YES;
    NSUInteger i;

    for (i = 0; i < sizeof (kinds) / sizeof (kinds[0]); i++)
      {
        Class windowClass = kinds[i].panel ? [NSPanel class] : [NSWindow class];
        NSWindow *window = [[windowClass alloc] initWithContentRect: NSMakeRect (500, 300, 260, 100)
                                                          styleMask: kinds[i].style
                                                            backing: NSBackingStoreBuffered
                                                              defer: NO];
        NSView *kindFrame = [[window contentView] superview];
        CGFloat top = QuirkProbeTopGap (kindFrame, [[window contentView] frame]);
        NSUInteger count = [QuirkProbeWindowButtons (kindFrame) count];
        BOOL edge = [kindFrame hitTest: NSMakePoint (2, 50)] == kindFrame;
        BOOL expectEdge = (kinds[i].style & NSResizableWindowMask) && !(kinds[i].style & NSFullScreenWindowMask);

        [window setTitle: @"Kind"];
        [parts addObject: [NSString stringWithFormat: @"%s %gpt, %lu button(s)%@", kinds[i].name, top,
          (unsigned long)count, edge ? @", resize edges" : @""]];
        ok = ok && top == kinds[i].top && count == kinds[i].buttons && edge == expectEdge;
        RELEASE (window);
      }
    detail = [parts componentsJoinedByString: @"; "];
    if (ok)
      [self pass: @"header-bar-window-kinds" detail: detail];
    else
      [self fail: @"header-bar-window-kinds" detail: detail];
  }

  /* A window that can only be closed: one button, at the end, which
     closes it. */
  {
    NSWindow *closable = [[NSWindow alloc] initWithContentRect: NSMakeRect (500, 420, 240, 80)
                                                     styleMask: NSTitledWindowMask | NSClosableWindowMask
                                                       backing: NSBackingStoreBuffered
                                                         defer: NO];
    NSView *closableFrame;
    NSArray *closableButtons;
    NSButton *button;

    [closable setReleasedWhenClosed: NO];
    [closable setTitle: @"Closable"];
    [closable orderFront: nil];
    closableFrame = [[closable contentView] superview];
    closableButtons = QuirkProbeWindowButtons (closableFrame);
    button = [closableButtons lastObject];
    detail = [NSString stringWithFormat: @"%lu button(s), the last at %@ in %@",
      (unsigned long)[closableButtons count], NSStringFromRect ([button frame]), NSStringFromRect ([closableFrame bounds])];
    [button performClick: nil];
    if ([closableButtons count] == 1 && [button tag] == NSWindowCloseButton
      && NSMaxX ([button frame]) == NSMaxX ([closableFrame bounds]) - 6 && [closable isVisible] == NO)
      [self pass: @"header-bar-close" detail: detail];
    else
      [self fail: @"header-bar-close" detail: [detail stringByAppendingString: [closable isVisible] ? @"; still open" : @""]];
    RELEASE (closable);
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

/* Tool tips and drag images are hidden by shrinking their window to
   NSZeroRect before ordering it out, which leaves them frozen under
   Mutter/Xwayland (GNOME/mutter#5080). On Wayland the theme keeps the size;
   elsewhere it leaves GNUstep's shrink alone. */
- (void) showForHiding: (NSWindow *)window
{
  [window setFrame: NSMakeRect (100, 100, 80, 24) display: NO];
  [window orderFront: nil];
}

- (void) checkHiddenWindow: (NSWindow *)window ident: (NSString *)ident
{
  BOOL wayland = (getenv ("WAYLAND_DISPLAY") != NULL);
  NSRect frame = [window frame];
  NSString *detail = [NSString stringWithFormat: @"%@ after hiding (%@), %@",
    NSStringFromSize (frame.size), wayland ? @"Wayland" : @"not Wayland",
    [window isVisible] ? @"still visible" : @"ordered out"];

  /* GNUstep clamps NSZeroRect to 1x1. */
  BOOL shrunk = (NSWidth (frame) <= 1 && NSHeight (frame) <= 1);

  if ([window isVisible] == NO && shrunk != wayland)
    {
      [self pass: ident detail: detail];
    }
  else
    {
      [self fail: ident detail: detail];
    }
}

/* A tool tip shown by GSToolTips itself: libadwaita's dark box with light
   text and its padding, no black border, in the interface font's size, and
   it stays put when it follows an unmoved pointer
   (plugins-themes-Adwaita#1). */
- (void) checkToolTip
{
  Class tipsClass = NSClassFromString (@"GSToolTips");
  NSView *anchor = [[_controlsWindow contentView] viewWithTag: 1];
  NSString *tipText = @"Zoom: Fit to Window";
  NSTimer *fake;
  id tips;
  NSWindow *panel = nil;
  NSEnumerator *enumerator;
  NSWindow *window;
  NSBitmapImageRep *rep;
  QuirkProbeInk edge, light;
  NSRect shown, followed;
  NSString *detail;

  if (tipsClass == Nil || anchor == nil)
    {
      [self skip: @"tooltip-adwaita" detail: @"GSToolTips not found"];
      return;
    }
  [anchor setToolTip: tipText];
  tips = [tipsClass performSelector: @selector(tipsForView:) withObject: anchor];
  fake = [NSTimer timerWithTimeInterval: 1000 target: self selector: @selector(finish)
                               userInfo: tipText repeats: NO];
  [tips performSelector: @selector(_timedOut:) withObject: fake];

  enumerator = [[NSApp windows] objectEnumerator];
  while ((window = [enumerator nextObject]) != nil)
    {
      if ([window isKindOfClass: NSClassFromString (@"GSTTPanel")] && [window isVisible])
        {
          panel = window;
        }
    }
  if (panel == nil)
    {
      [self fail: @"tooltip-adwaita" detail: @"no tool tip window shown"];
      return;
    }
  shown = [panel frame];
  [tips performSelector: @selector(mouseMoved:) withObject: nil];
  followed = [panel frame];

  rep = QuirkProbeRender ([panel contentView]);
  QuirkProbeInkBackground = 0;
  light = QuirkProbeMeasure (rep, QuirkProbeIsWhite);
  edge = QuirkProbeMeasureIn (rep, QuirkProbeIsAnyPixel, NSMakeRect (0, 0, 1, [rep pixelsHigh]));
  QuirkProbeInkBackground = 750;
  detail = [NSString stringWithFormat: @"%gx%g; text ink %ldx%ld at %ld,%ld; edge r+g+b %lu-%lu; "
    @"%@ after following an unmoved pointer",
    NSWidth (shown), NSHeight (shown), (long)light.width, (long)light.height,
    (long)light.minX, (long)light.minY, (unsigned long)edge.darkest, (unsigned long)edge.lightest,
    NSEqualRects (shown, followed) ? @"same frame" : NSStringFromRect (followed)];

  if (light.count > 0 && light.minX >= 8 && light.minY >= 4
    && light.minX + light.width <= NSWidth (shown) - 8
    && light.height >= 10
    && edge.lightest < 200 && edge.lightest - edge.darkest < 30
    && NSEqualRects (shown, followed))
    {
      [self pass: @"tooltip-adwaita" detail: detail];
    }
  else
    {
      [self fail: @"tooltip-adwaita" detail: detail];
    }
  [tips performSelector: @selector(_endDisplay)];
  [anchor setToolTip: nil];
}

- (void) checkHiddenWindows
{
  Class panelClass = NSClassFromString (@"GSTTPanel");
  GSDragView *dragView = [GSDragView sharedDragView];

  if (panelClass == Nil)
    {
      [self skip: @"tooltip-hide-keeps-size" detail: @"GSTTPanel not found"];
    }
  else
    {
      NSWindow *panel = [[panelClass alloc] initWithContentRect: NSMakeRect (0, 0, 100, 25)
                                                      styleMask: NSBorderlessWindowMask
                                                        backing: NSBackingStoreRetained
                                                          defer: YES];

      /* Hidden as -[GSToolTips _endDisplay:] does it. */
      [panel setReleasedWhenClosed: NO];
      [self showForHiding: panel];
      [panel setFrame: NSZeroRect display: NO];
      [panel orderOut: nil];
      [self checkHiddenWindow: panel ident: @"tooltip-hide-keeps-size"];
      RELEASE (panel);
    }

  [self showForHiding: [dragView window]];
  [dragView performSelector: @selector(_clearupWindow)];
  [self checkHiddenWindow: [dragView window] ident: @"drag-image-hide-keeps-size"];
}

- (void) checkFirstWindows: (NSTimer *)timer
{
  /* -ProbeOnly header-bar: the header bar's checks alone, for the dark and
     high contrast runs (the other checks assume the light palette). */
  if ([[[NSUserDefaults standardUserDefaults] stringForKey: @"ProbeOnly"] isEqualToString: @"header-bar"])
    {
      [self checkHeaderBar];
      [self finish];
      return;
    }
  [self saveWindow: _controlsWindow named: @"controls"];
  [self saveWindow: _toolbarWindow named: @"toolbar"];
  [self saveWindow: _tableWindow named: @"tables"];
  [self checkSizedButtons];
  [self checkFixedButtons];
  [self checkSteppers];
  [self checkColorWell];
  [self checkLabels];
  [self checkToolbar];
  [self checkTables];
  [self checkMenuBar];
  [self checkToolbarEdges];
  [self checkToolbarHover];
  [self checkPopUpButton];
  [self checkButtonFocusRing];
  [self checkCheckboxGap];
  [self checkTableDensity];
  [self checkTabView];
  [self checkToolbarDisplayMode];
  [self checkApplicationMenuPosition];
  [self checkCocoaApplicationMenu];
  [self checkGormControls];
  [self checkMetricsMode];
  [self checkPrimaryMenu];
  [self checkHeaderBar];
  [self checkFonts];
  [self checkToolTip];
  [self checkHiddenWindows];

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
  [self checkAlertLayout: panel];
  /* With the header bar, an alert has none (as AdwAlertDialog): a 1pt
     border round its content, and it can still take the keyboard (it
     isn't key here: the late window is, on a display without a window
     manager). */
  if (QuirkProbeDrawsDecorations ())
    {
      NSView *frameView = [[panel contentView] superview];
      CGFloat top = QuirkProbeTopGap (frameView, [[panel contentView] frame]);
      NSString *detail = [NSString stringWithFormat: @"content %gpt from the top, %@ buttons, %@",
        top, [QuirkProbeWindowButtons (frameView) count] > 0 ? @"with" : @"no",
        [panel canBecomeKeyWindow] ? @"can become key" : @"can't become key"];

      if (top == 1 && [QuirkProbeWindowButtons (frameView) count] == 0 && [panel canBecomeKeyWindow])
        [self pass: @"header-bar-alert" detail: detail];
      else
        [self fail: @"header-bar-alert" detail: detail];
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

/* Laid out like AdwAlertDialog: no icon or line, the heading centred, the
   buttons one row of equal widths with the default (Remove) at the right. */
- (void) checkAlertLayout: (NSWindow *)panel
{
  NSEnumerator *enumerator = [[[panel contentView] subviews] objectEnumerator];
  NSView *view;
  NSButton *remove = nil, *cancel = nil;
  NSUInteger visibleIcons = 0, visibleLines = 0;
  NSTextField *heading = (NSTextField *)QuirkProbeFindText ([panel contentView], @"Remove this library?");
  NSString *detail;

  while ((view = [enumerator nextObject]) != nil)
    {
      if ([view isHidden])
        {
          continue;
        }
      if ([view isKindOfClass: [NSBox class]])
        {
          visibleLines++;
        }
      else if ([view isKindOfClass: [NSButton class]])
        {
          NSString *title = [(NSButton *)view title];

          if ([title isEqualToString: @"Remove"])
            remove = (NSButton *)view;
          else if ([title isEqualToString: @"Cancel"])
            cancel = (NSButton *)view;
          else if ([(NSButton *)view isBordered] == NO)
            visibleIcons++;
        }
    }
  detail = [NSString stringWithFormat: @"%lu icons, %lu lines; Remove %@, Cancel %@; heading %@",
    (unsigned long)visibleIcons, (unsigned long)visibleLines,
    NSStringFromRect ([remove frame]), NSStringFromRect ([cancel frame]),
    [heading alignment] == NSCenterTextAlignment ? @"centred" : @"not centred"];
  if (remove != nil && cancel != nil && visibleIcons == 0 && visibleLines == 0
    && NSWidth ([remove frame]) == NSWidth ([cancel frame])
    && NSMinY ([remove frame]) == NSMinY ([cancel frame])
    && NSMinX ([remove frame]) > NSMaxX ([cancel frame])
    && [heading alignment] == NSCenterTextAlignment)
    {
      [self pass: @"alert-adwaita-layout" detail: detail];
    }
  else
    {
      [self fail: @"alert-adwaita-layout" detail: detail];
    }
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
