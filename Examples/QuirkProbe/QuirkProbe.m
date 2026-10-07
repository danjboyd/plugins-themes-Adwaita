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

/* From the theme (GnomeThemeMenusAndData.m): a narrow menu bar's overflow
   button and the menu it shows. */
@interface NSMenuView (QuirkProbeMenuBarOverflow)
- (NSRect) gnomeThemeOverflowRect;
- (NSMenu *) gnomeThemeOverflowMenu;
@end

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

/* An icon-only toolbar as a GNOME-style app makes it: an image item and a
   34pt button (libadwaita's size) as a view item. */
@interface QuirkProbeRowToolbarDelegate : NSObject
{
@public
  BOOL _emptyLabels;
}
@end

@implementation QuirkProbeRowToolbarDelegate

- (NSToolbarItem *) toolbar: (NSToolbar *)toolbar
      itemForItemIdentifier: (NSString *)identifier
  willBeInsertedIntoToolbar: (BOOL)flag
{
  NSToolbarItem *item = AUTORELEASE ([[NSToolbarItem alloc] initWithItemIdentifier: identifier]);

  [item setLabel: _emptyLabels ? @"" : identifier];
  if ([identifier isEqualToString: @"Image"])
    {
      NSImage *image = AUTORELEASE ([[NSImage alloc] initWithSize: NSMakeSize (16, 16)]);

      [image lockFocus];
      [[NSColor blackColor] set];
      NSRectFill (NSMakeRect (0, 0, 16, 16));
      [image unlockFocus];
      [item setImage: image];
      [item setTarget: self];
      [item setAction: @selector(description)];
    }
  else
    {
      NSButton *button = AUTORELEASE ([[NSButton alloc] initWithFrame: NSMakeRect (0, 0, 34, 34)]);

      [button setTitle: @"B"];
      [item setView: button];
      [item setMinSize: NSMakeSize (34, 34)];
      [item setMaxSize: NSMakeSize (34, 34)];
    }
  return item;
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *)toolbar
{
  return [NSArray arrayWithObjects: @"Image", NSToolbarSeparatorItemIdentifier, @"Button",
                   NSToolbarFlexibleSpaceItemIdentifier, nil];
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *)toolbar
{
  return [self toolbarAllowedItemIdentifiers: toolbar];
}

@end

/* The theme's, from Source/Rendering/GnomeThemeWindowTypes.m and
   GnomeThemeHeaderBar.m. */
@interface NSObject (QuirkProbeGnomeTheme)
+ (NSString *) windowTypeForWindow: (NSWindow *)window;
- (BOOL) holdsToolbarInBar;
- (NSString *) view: (NSView *)view stringForToolTip: (NSToolTipTag)tag point: (NSPoint)point
           userData: (void *)data;
@end

@interface NSToolbar (QuirkProbePrivate)
- (NSView *) _toolbarView;
@end

@interface NSToolbarItem (QuirkProbePrivate)
- (NSView *) _backView;
@end

/* A toolbar as a GNOME app packs its header bar: two icons at the start, a
   flexible space, a text button and an icon at the end. */
@interface QuirkProbeHeaderToolbarDelegate : NSObject
@end

@implementation QuirkProbeHeaderToolbarDelegate

- (NSToolbarItem *) toolbar: (NSToolbar *)toolbar
      itemForItemIdentifier: (NSString *)identifier
  willBeInsertedIntoToolbar: (BOOL)flag
{
  NSToolbarItem *item = AUTORELEASE ([[NSToolbarItem alloc] initWithItemIdentifier: identifier]);

  [item setLabel: identifier];
  [item setTarget: self];
  [item setAction: @selector(description)];
  if ([identifier hasPrefix: @"Icon"])
    {
      NSImage *image = AUTORELEASE ([[NSImage alloc] initWithSize: NSMakeSize (16, 16)]);

      [image lockFocus];
      [[NSColor blackColor] set];
      NSRectFill (NSMakeRect (4, 4, 8, 8));
      [image unlockFocus];
      [item setImage: image];
    }
  return item;
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *)toolbar
{
  return [NSArray arrayWithObjects: @"IconA", @"IconB", NSToolbarFlexibleSpaceItemIdentifier, @"Share", @"IconC", nil];
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *)toolbar
{
  return [self toolbarAllowedItemIdentifiers: toolbar];
}

@end

/* A toolbar item's view that acts on the release only, as ScreenshotTool's
   Copy and zoom items did (plugins-themes-Adwaita#33). */
@interface QuirkProbeReleaseView : NSView
{
@public
  int releases;
}
@end

@implementation QuirkProbeReleaseView

- (void) mouseUp: (NSEvent *)event
{
  releases++;
}

- (void) drawRect: (NSRect)rect
{
  [[NSColor grayColor] set];
  NSRectFill ([self bounds]);
}

@end

@interface QuirkProbeReleaseToolbarDelegate : NSObject
{
@public
  QuirkProbeReleaseView *view;
}
@end

@implementation QuirkProbeReleaseToolbarDelegate

- (NSToolbarItem *) toolbar: (NSToolbar *)toolbar
      itemForItemIdentifier: (NSString *)identifier
  willBeInsertedIntoToolbar: (BOOL)flag
{
  NSToolbarItem *item = AUTORELEASE ([[NSToolbarItem alloc] initWithItemIdentifier: identifier]);

  [item setLabel: identifier];
  if ([identifier isEqualToString: @"Release"])
    {
      view = AUTORELEASE ([[QuirkProbeReleaseView alloc] initWithFrame: NSMakeRect (0, 0, 32, 28)]);
      [item setView: view];
      [item setMinSize: NSMakeSize (32, 28)];
      [item setMaxSize: NSMakeSize (32, 28)];
    }
  return item;
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *)toolbar
{
  return [NSArray arrayWithObjects: @"Release", NSToolbarFlexibleSpaceItemIdentifier, nil];
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *)toolbar
{
  return [self toolbarAllowedItemIdentifiers: toolbar];
}

@end

/* A toolbar with an item that is only a container (a plain view, as
   MarkdownViewer's status area) and one that is a label
   (plugins-themes-Adwaita#36). */
@interface QuirkProbeDragToolbarDelegate : NSObject
{
@public
  NSView *box;
  NSTextField *label;
}
@end

@implementation QuirkProbeDragToolbarDelegate

- (NSToolbarItem *) toolbar: (NSToolbar *)toolbar
      itemForItemIdentifier: (NSString *)identifier
  willBeInsertedIntoToolbar: (BOOL)flag
{
  NSToolbarItem *item = AUTORELEASE ([[NSToolbarItem alloc] initWithItemIdentifier: identifier]);

  [item setLabel: identifier];
  if ([identifier isEqualToString: @"Box"])
    {
      box = AUTORELEASE ([[NSView alloc] initWithFrame: NSMakeRect (0, 0, 80, 28)]);
      [item setView: box];
      [item setMinSize: NSMakeSize (80, 28)];
      [item setMaxSize: NSMakeSize (80, 28)];
    }
  else if ([identifier isEqualToString: @"Label"])
    {
      label = AUTORELEASE ([[NSTextField alloc] initWithFrame: NSMakeRect (0, 0, 80, 20)]);
      [label setStringValue: @"Status"];
      [label setEditable: NO];
      [label setSelectable: NO];
      [label setBezeled: NO];
      [label setDrawsBackground: NO];
      [item setView: label];
      [item setMinSize: NSMakeSize (80, 20)];
      [item setMaxSize: NSMakeSize (80, 20)];
    }
  return item;
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *)toolbar
{
  return [NSArray arrayWithObjects: @"Box", @"Label", NSToolbarFlexibleSpaceItemIdentifier, nil];
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *)toolbar
{
  return [self toolbarAllowedItemIdentifiers: toolbar];
}

@end

/* An icon-only toolbar of plain views with fixed sizes (minSize = maxSize =
   the view's frame) around a flexible space, as ScreenshotTool makes it. */
@interface QuirkProbeViewItemToolbarDelegate : NSObject
@end

@implementation QuirkProbeViewItemToolbarDelegate

- (NSToolbarItem *) toolbar: (NSToolbar *)toolbar
      itemForItemIdentifier: (NSString *)identifier
  willBeInsertedIntoToolbar: (BOOL)flag
{
  NSToolbarItem *item = AUTORELEASE ([[NSToolbarItem alloc] initWithItemIdentifier: identifier]);
  NSView *view = AUTORELEASE ([[NSView alloc] initWithFrame:
    NSMakeRect (0, 0, [identifier isEqualToString: @"Wide"] ? 104 : 40, 32)]);

  [item setLabel: identifier];
  [item setView: view];
  [item setMinSize: [view frame].size];
  [item setMaxSize: [view frame].size];
  return item;
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *)toolbar
{
  return [NSArray arrayWithObjects: @"Narrow", NSToolbarFlexibleSpaceItemIdentifier, @"Wide", nil];
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *)toolbar
{
  return [self toolbarAllowedItemIdentifiers: toolbar];
}

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

  /* A preferences window that exists when the menu is first attached
     (plugins-themes-Adwaita#4), resizable as a main window. */
  _launchPrefsWindow = [[NSWindow alloc] initWithContentRect: NSMakeRect (960, 420, 260, 100)
                                                   styleMask: (NSTitledWindowMask | NSClosableWindowMask
                                                               | NSMiniaturizableWindowMask | NSResizableWindowMask)
                                                     backing: NSBackingStoreBuffered
                                                       defer: NO];
  [_launchPrefsWindow setTitle: @"Preferences"];
  [_launchPrefsWindow setReleasedWhenClosed: NO];
  [_windows addObject: _launchPrefsWindow];
  RELEASE (_launchPrefsWindow);
  [_launchPrefsWindow orderFront: nil];

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

/* The theme's GSThemeDomain (interface styles, backend defaults) reached
   the app: it was in the bundle's Info-gnustep.plist, which a clean build
   once replaced with gnustep-make's generated one (#45). */
- (void) checkThemeDomain
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSDictionary *domain = [defaults volatileDomainForName: @"GSThemeDomain"];
  BOOL searched = [[defaults searchList] containsObject: @"GSThemeDomain"];
  NSString *style = [domain objectForKey: @"NSMenuInterfaceStyle"];
  NSString *detail = [NSString stringWithFormat: @"in search list %d, %lu keys, NSMenuInterfaceStyle %@",
    searched, (unsigned long)[domain count], style];

  if (searched && [style isEqualToString: @"NSWindows95InterfaceStyle"]
    && [domain objectForKey: @"GSBackHandlesWindowDecorations"] != nil)
    {
      [self pass: @"theme-domain" detail: detail];
    }
  else
    {
      [self fail: @"theme-domain" detail: detail];
    }
}

/* Text about as wide as GTK 4's at GNOME's font (#23): the widths GTK 4.18
   gives these strings at Cantarell 11 with GNOME's settings (unhinted
   metrics), measured on 2026-10-07 with a GtkLabel's Pango layout. GNUstep
   measures them with -sizeWithAttributes: and an NSLayoutManager, both of
   which use screen fonts. Before #23 a screen font was a whole pixel size
   up (15 for 14.67) and the strings came out 3.1% and 2.7% wider (296 and
   423). The theme keeps libs-back's hinted metrics, whole-pixel advances,
   which come to 283 and 407: 1.4% and 1.1% narrower than GTK's. */
- (void) checkTextWidth
{
  NSFont *font = [NSFont systemFontOfSize: 0];
  NSString *strings[2] = {
    @"The quick brown fox jumps over the lazy dog",
    @"Are you sure you want to discard the changes to this document?" };
  CGFloat gtk[2] = { 287.094, 411.679 };
  NSMutableString *detail = [NSMutableString string];
  BOOL ok = YES;
  int i;

  if (font == nil || [[font familyName] isEqualToString: @"Cantarell"] == NO
    || fabs ([font pointSize] - 11.0 * 96.0 / 72.0) > 0.01)
    {
      [self skip: @"text-width" detail: [NSString stringWithFormat:
        @"needs Cantarell at 14.667 (have %@ %.3f)", [font fontName], [font pointSize]]];
      return;
    }
  for (i = 0; i < 2; i++)
    {
      NSDictionary *attrs = [NSDictionary dictionaryWithObject: font forKey: NSFontAttributeName];
      NSTextStorage *storage = [[NSTextStorage alloc] initWithString: strings[i] attributes: attrs];
      NSLayoutManager *layout = [NSLayoutManager new];
      NSTextContainer *container = [[NSTextContainer alloc] initWithContainerSize: NSMakeSize (10000, 1000)];
      CGFloat drawn = [strings[i] sizeWithAttributes: attrs].width;
      CGFloat laidOut;

      [container setLineFragmentPadding: 0];
      [layout addTextContainer: container];
      [storage addLayoutManager: layout];
      [layout glyphRangeForTextContainer: container];
      laidOut = NSWidth ([layout usedRectForTextContainer: container]);
      /* Within 2%: hinted advances, but not the screen font's larger size. */
      if (fabs (drawn / gtk[i] - 1.0) > 0.02 || fabs (laidOut / gtk[i] - 1.0) > 0.02)
        {
          ok = NO;
        }
      [detail appendFormat: @"%s%.3f and %.3f for GTK's %.3f", i ? "; " : "", drawn, laidOut, gtk[i]];
      [container release];
      [layout release];
      [storage release];
    }
  if (ok)
    {
      [self pass: @"text-width" detail: detail];
    }
  else
    {
      [self fail: @"text-width" detail: detail];
    }
}

/* GNOME's text-scaling-factor (Large Text; -ProbeTextScale is what the run
   set in the probe's GSettings): the interface and monospace fonts are
   Cantarell 11 and Noto Sans Mono 11 at 96 dpi times the factor, the menu
   rows follow the larger text, and compact metrics (windows laid out at
   GNUstep's sizes) keep GNUstep's 12pt (#53). */
- (void) checkTextScaling
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  CGFloat factor = [defaults floatForKey: @"ProbeTextScale"];
  CGFloat expected;
  NSFont *font = [NSFont systemFontOfSize: 0];
  NSFont *fixed = [NSFont userFixedPitchFontOfSize: 0];
  CGFloat menuItem = [defaults floatForKey: @"GSMenuItemHeight"];
  CGFloat compactSize = -1.0;
  id theme = [GSTheme theme];
  id settings = nil;
  NSString *detail;
  BOOL ok;

  if (factor <= 0.0)
    {
      factor = 1.0;
    }
  expected = 11.0 * 96.0 / 72.0 * factor;
  if ([theme respondsToSelector: @selector(settings)])
    {
      settings = [theme performSelector: @selector(settings)];
    }
  if ([settings respondsToSelector: @selector(compactInterfaceFontSize)])
    {
      CGFloat (*sizeIMP)(id, SEL) = (CGFloat (*)(id, SEL))[settings methodForSelector: @selector(compactInterfaceFontSize)];

      compactSize = sizeIMP (settings, @selector(compactInterfaceFontSize));
    }
  if (font == nil || [[font familyName] isEqualToString: @"Cantarell"] == NO)
    {
      [self skip: @"text-scaling" detail: [NSString stringWithFormat:
        @"needs Cantarell (have %@)", [font fontName]]];
      return;
    }
  ok = (fabs ([font pointSize] - expected) < 0.01
    && fixed != nil && fabs ([fixed pointSize] - expected) < 0.01
    && fabs (menuItem - ceil (MAX (32.0, expected + 19.0))) < 0.5
    && fabs (compactSize - 12.0) < 0.01);
  detail = [NSString stringWithFormat:
    @"factor %.2f: interface %.3f, monospace %@ %.3f (want %.3f); menu item %.0f (want %.0f); compact %.3f (want 12)",
    factor, [font pointSize], [fixed familyName], [fixed pointSize], expected,
    menuItem, ceil (MAX (32.0, expected + 19.0)), compactSize];
  if (ok)
    {
      [self pass: @"text-scaling" detail: detail];
    }
  else
    {
      [self fail: @"text-scaling" detail: detail];
    }
}

/* +imageNamed: calls for the images the theme classifies buttons by,
   counted while -checkImageFreeButton runs (#50). */
static IMP QuirkProbeImageNamedIMP = NULL;
static NSUInteger QuirkProbeClassifyLookups = 0;

static id
QuirkProbeCountingImageNamed (id receiver, SEL selector, NSString *name)
{
  static NSSet *names = nil;

  if (names == nil)
    {
      names = [[NSSet alloc] initWithObjects: @"NSSwitch", @"NSHighlightedSwitch",
        @"NSRadioButton", @"NSHighlightedRadioButton", @"common_ret",
        @"common_retH", @"GSSearch", @"GSStop", nil];
    }
  if ([names containsObject: name])
    {
      QuirkProbeClassifyLookups++;
    }
  return ((id (*)(id, SEL, NSString *))QuirkProbeImageNamedIMP) (receiver, selector, name);
}

/* A button with a title and no image is sized and drawn without the theme
   looking up the checkbox, radio, return-key, search or stop images: the
   first lookup of each loads it, and they cost about 120ms on the first
   button an app drew (#50). */
- (void) checkImageFreeButton
{
  Method method = class_getClassMethod ([NSImage class], @selector(imageNamed:));
  NSWindow *window = [self windowWithFrame: NSMakeRect (0, 0, 200, 60) title: @"Image-free button"];
  NSButton *button;
  NSUInteger lookups;

  QuirkProbeClassifyLookups = 0;
  QuirkProbeImageNamedIMP = method_setImplementation (method, (IMP)QuirkProbeCountingImageNamed);
  button = [[NSButton alloc] initWithFrame: NSMakeRect (20, 13, 120, 34)];
  [button setTitle: @"Plain"];
  [[window contentView] addSubview: button];
  [[button cell] cellSize];
  QuirkProbeRender (button);
  method_setImplementation (method, QuirkProbeImageNamedIMP);
  lookups = QuirkProbeClassifyLookups;
  [button release];
  [window orderOut: nil];

  if (lookups == 0)
    {
      [self pass: @"image-free-button" detail: @"sized and drawn with no classification image looked up"];
    }
  else
    {
      [self fail: @"image-free-button" detail: [NSString stringWithFormat:
        @"%lu lookups of classification images", (unsigned long)lookups]];
    }
}

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

/* A toolbar's row as libadwaita's: 46pt for icons or labels alone, sized
   to the content for icons with labels, keeping a 34pt button view, with
   spaces and separators not setting the height (plugins-themes-Adwaita#8). */
- (NSString *) measureToolbarRowMode: (NSToolbarDisplayMode)mode
                                size: (NSToolbarSizeMode)sizeMode
                         emptyLabels: (BOOL)emptyLabels
                              height: (CGFloat *)height
                                  ok: (BOOL *)ok
{
  /* Toolbars don't retain their delegate; the windows live on. */
  QuirkProbeRowToolbarDelegate *delegate = [QuirkProbeRowToolbarDelegate new];
  NSWindow *window = [self windowWithFrame: NSMakeRect (40, 300, 360, 120) title: @"QuirkProbe Toolbar Row"];
  NSString *identifier = [NSString stringWithFormat: @"QuirkProbeRow%d%d%d", (int)mode, (int)sizeMode, (int)emptyLabels];
  NSToolbar *toolbar = AUTORELEASE ([[NSToolbar alloc] initWithIdentifier: identifier]);
  NSView *frameView, *toolbarView, *buttonView;
  NSRect toolbarFrame, contentFrame;
  NSSize imageSize;
  BOOL viewShown;

  delegate->_emptyLabels = emptyLabels;
  [toolbar setDelegate: delegate];
  [toolbar setDisplayMode: mode];
  [toolbar setSizeMode: sizeMode];
  [window setToolbar: toolbar];
  [window orderFront: nil];
  [window display];
  frameView = [[window contentView] superview];
  toolbarView = QuirkProbeFindViewOfClass (frameView, NSClassFromString (@"GSToolbarView"));
  buttonView = [[[toolbar items] objectAtIndex: 2] view];
  imageSize = [[[[toolbar items] objectAtIndex: 0] image] size];
  toolbarFrame = [frameView convertRect: [toolbarView bounds] fromView: toolbarView];
  contentFrame = [frameView convertRect: [[window contentView] bounds] fromView: [window contentView]];
  viewShown = ([buttonView window] == window);
  *height = NSHeight (toolbarFrame);
  *ok = (toolbarView != nil && NSMaxY (contentFrame) <= NSMinY (toolbarFrame) + 0.5
    && (viewShown || mode == NSToolbarDisplayModeLabelOnly)
    && imageSize.width <= (sizeMode == NSToolbarSizeModeSmall ? 16 : 24));
  [window orderOut: nil];
  return [NSString stringWithFormat: @"%gpt%@, image %gx%g", NSHeight (toolbarFrame),
    viewShown ? @"" : @" (no button view)", imageSize.width, imageSize.height];
}

- (void) checkToolbarRowHeight
{
  CGFloat iconOnly, emptyLabels, labelOnly, small, labelled;
  BOOL ok1, ok2, ok3, ok4, ok5;
  NSString *detail = [NSString stringWithFormat: @"icon only %@; icon and label, empty labels %@; label only %@; "
    @"small icon only %@; icon and label %@",
    [self measureToolbarRowMode: NSToolbarDisplayModeIconOnly size: NSToolbarSizeModeRegular emptyLabels: NO
                         height: &iconOnly ok: &ok1],
    [self measureToolbarRowMode: NSToolbarDisplayModeIconAndLabel size: NSToolbarSizeModeRegular emptyLabels: YES
                         height: &emptyLabels ok: &ok2],
    [self measureToolbarRowMode: NSToolbarDisplayModeLabelOnly size: NSToolbarSizeModeRegular emptyLabels: NO
                         height: &labelOnly ok: &ok3],
    [self measureToolbarRowMode: NSToolbarDisplayModeIconOnly size: NSToolbarSizeModeSmall emptyLabels: NO
                         height: &small ok: &ok4],
    [self measureToolbarRowMode: NSToolbarDisplayModeIconAndLabel size: NSToolbarSizeModeRegular emptyLabels: NO
                         height: &labelled ok: &ok5]];

  if ([[[NSUserDefaults standardUserDefaults] stringForKey: @"GnomeThemeMetrics"] isEqualToString: @"compact"])
    {
      [self skip: @"toolbar-row-height" detail: @"compact metrics keep libs-gui's toolbar layout"];
    }
  else if (ok1 && ok2 && ok3 && ok4 && ok5
    && iconOnly >= 46 && iconOnly <= 48 && emptyLabels >= 46 && emptyLabels <= 48
    && labelOnly >= 46 && labelOnly <= 48 && small >= 46 && small <= 48
    && labelled > 48 && labelled < 62)
    {
      [self pass: @"toolbar-row-height" detail: detail];
    }
  else
    {
      [self fail: @"toolbar-row-height" detail: detail];
    }
}

/* A view item keeps its fixed width through layouts: libs-gui sets each
   view to its slot less 10pt insets, and with the theme's narrower slots
   views lost 14pt a layout down to nothing (plugins-themes-Adwaita#9). */
- (void) checkToolbarViewItemWidth
{
  /* Toolbars don't retain their delegate; the windows live on. */
  QuirkProbeViewItemToolbarDelegate *delegate = [QuirkProbeViewItemToolbarDelegate new];
  NSWindow *window = [self windowWithFrame: NSMakeRect (40, 300, 400, 120) title: @"QuirkProbe Toolbar Views"];
  NSToolbar *toolbar = AUTORELEASE ([[NSToolbar alloc] initWithIdentifier: @"QuirkProbeViewItems"]);
  NSMutableString *detail = [NSMutableString string];
  BOOL ok = YES;
  NSEnumerator *enumerator;
  NSToolbarItem *item;
  int i;

  [toolbar setDelegate: delegate];
  [toolbar setDisplayMode: NSToolbarDisplayModeIconOnly];
  [toolbar setSizeMode: NSToolbarSizeModeRegular];
  [window setToolbar: toolbar];
  [window orderFront: nil];
  /* Each resize lays the toolbar out again. */
  for (i = 0; i < 4; i++)
    {
      NSRect frame = [window frame];

      frame.size.width += (i % 2) ? -20 : 20;
      [window setFrame: frame display: YES];
    }
  enumerator = [[toolbar items] objectEnumerator];
  while ((item = [enumerator nextObject]) != nil)
    {
      NSView *view = [item view];
      NSView *slot = [view superview];

      if (view == nil)
        {
          continue;
        }
      [detail appendFormat: @"%@%@ %gpt in a %gpt slot", [detail length] ? @"; " : @"", [item itemIdentifier],
        NSWidth ([view frame]), NSWidth ([slot frame])];
      ok = ok && slot != nil && NSWidth ([view frame]) == [item minSize].width
        && NSWidth ([slot frame]) >= [item minSize].width;
    }
  [window orderOut: nil];
  if ([[[NSUserDefaults standardUserDefaults] stringForKey: @"GnomeThemeMetrics"] isEqualToString: @"compact"])
    {
      [self skip: @"toolbar-view-item-width" detail: @"compact metrics keep libs-gui's toolbar layout"];
    }
  else if (ok)
    {
      [self pass: @"toolbar-view-item-width" detail: detail];
    }
  else
    {
      [self fail: @"toolbar-view-item-width" detail: detail];
    }
}

/* A vertical menu as libadwaita's popover menus: a separator is one
   hairline at 15% of the text colour (plugins-themes-Adwaita#11: two rows
   of mid grey), and shortcuts end 12pt inside the row, 16pt from the
   cell's edge (the row is inset 4pt), with submenu arrows' boxes (#10:
   flush against the edge). */
/* An inline button row (#42): three items declared as one group share a
   row, side by side, and a click in each lands on it; the menu is three
   rows high, not five. */
- (void) checkInlineMenuRow
{
  NSMenu *menu = AUTORELEASE ([[NSMenu alloc] initWithTitle: @"View"]);
  NSArray *titles = [NSArray arrayWithObjects: @"Before", @"Zoom Out", @"110%", @"Zoom In", @"After", nil];
  NSWindow *window;
  NSMenuView *menuView;
  NSRect rects[5];
  NSMutableArray *problems = [NSMutableArray array];
  NSInteger i;
  CGFloat rowHeight;
  QuirkProbeInk ink;

  for (i = 0; i < 5; i++)
    {
      NSMenuItem *item = (NSMenuItem *)[menu addItemWithTitle: [titles objectAtIndex: i]
                                                       action: @selector(description)
                                                keyEquivalent: @""];

      [item setTarget: self];
      if (i >= 1 && i <= 3)
        {
          [item setRepresentedObject: @"GnomeThemeInlineGroup:zoom"];
        }
    }
  menuView = AUTORELEASE ([[NSMenuView alloc] initWithFrame: NSMakeRect (0, 0, 200, 100)]);
  [menuView setMenu: menu];
  [menuView sizeToFit];
  window = [self windowWithFrame: NSMakeRect (40, 200, NSWidth ([menuView frame]) + 40, NSHeight ([menuView frame]) + 40)
                           title: @"QuirkProbe Inline Row"];
  [menuView setFrameOrigin: NSMakePoint (20, 20)];
  [[window contentView] addSubview: menuView];
  [window orderFront: nil];
  [window display];
  for (i = 0; i < 5; i++)
    {
      rects[i] = [menuView rectOfItemAtIndex: i];
    }
  rowHeight = NSHeight (rects[0]);
  for (i = 1; i <= 3; i++)
    {
      NSPoint middle = NSMakePoint (NSMidX (rects[i]), NSMidY (rects[i]));

      if (NSMinY (rects[i]) != NSMinY (rects[1]) || NSHeight (rects[i]) != rowHeight)
        {
          [problems addObject: [NSString stringWithFormat: @"item %ld not on the row: %@", (long)i,
                                         NSStringFromRect (rects[i])]];
        }
      if (i > 1 && NSMinX (rects[i]) < NSMaxX (rects[i - 1]))
        {
          [problems addObject: [NSString stringWithFormat: @"items %ld and %ld overlap", (long)(i - 1), (long)i]];
        }
      if ([menuView indexOfItemAtPoint: middle] != i)
        {
          [problems addObject: [NSString stringWithFormat: @"a click on item %ld finds %ld", (long)i,
                                         (long)[menuView indexOfItemAtPoint: middle]]];
        }
    }
  /* Three rows and the menu's padding, under four rows. */
  if (NSHeight ([menuView frame]) >= 4 * rowHeight)
    {
      [problems addObject: [NSString stringWithFormat: @"menu %g high for rows of %g",
                                     NSHeight ([menuView frame]), rowHeight]];
    }
  /* The middle item's title is drawn in its own segment. */
  {
    NSBitmapImageRep *rep = QuirkProbeRender (menuView);
    NSRect area = rects[2];

    if ([menuView isFlipped] == NO)
      {
        area.origin.y = NSHeight ([menuView bounds]) - NSMaxY (area);
      }
    ink = QuirkProbeMeasureIn (rep, QuirkProbeIsTextInk, area);
    if (ink.count < 20)
      {
        [problems addObject: [NSString stringWithFormat: @"no title in the middle segment %@", NSStringFromRect (area)]];
      }
  }
  [window orderOut: nil];
  if ([problems count] == 0)
    {
      [self pass: @"menu-inline-row"
          detail: [NSString stringWithFormat: @"%@ | %@ | %@", NSStringFromRect (rects[1]), NSStringFromRect (rects[2]),
                            NSStringFromRect (rects[3])]];
    }
  else
    {
      [self fail: @"menu-inline-row" detail: [problems componentsJoinedByString: @"; "]];
    }
}

/* A text field whose background the app chose (Gorm's CustomView palette
   item: dark gray, white bold text, not editable) fills with that colour;
   a plain read-only field keeps the theme's (#27). */
static BOOL
QuirkProbeIsDarkFill (NSUInteger red, NSUInteger green, NSUInteger blue)
{
  return red + green + blue < 330;
}

static BOOL
QuirkProbeIsWhiteText (NSUInteger red, NSUInteger green, NSUInteger blue)
{
  return red + green + blue > 720;
}

- (void) checkCustomBackgroundField
{
  NSWindow *window = [self windowWithFrame: NSMakeRect (60, 500, 280, 80) title: @"QuirkProbe Fields"];
  NSView *view = [window contentView];
  NSTextField *custom = AUTORELEASE ([[NSTextField alloc] initWithFrame: NSMakeRect (10, 20, 120, 40)]);
  NSTextField *plain = AUTORELEASE ([[NSTextField alloc] initWithFrame: NSMakeRect (150, 20, 120, 40)]);
  NSBitmapImageRep *rep;
  NSRect middle;
  QuirkProbeInk dark, white, plainDark;
  NSString *detail;

  [custom setBackgroundColor: [NSColor darkGrayColor]];
  [custom setTextColor: [NSColor whiteColor]];
  [custom setDrawsBackground: YES];
  [custom setAlignment: NSCenterTextAlignment];
  [custom setFont: [NSFont boldSystemFontOfSize: 0]];
  [custom setEditable: NO];
  [custom setSelectable: NO];
  [custom setStringValue: @"CustomView"];
  [plain setEditable: NO];
  [plain setSelectable: NO];
  [plain setStringValue: @"Plain"];
  [view addSubview: custom];
  [view addSubview: plain];
  [window orderFront: nil];
  [window display];

  rep = QuirkProbeRender (custom);
  middle = NSMakeRect (10, 6, [rep pixelsWide] - 20, [rep pixelsHigh] - 12);
  dark = QuirkProbeMeasureIn (rep, QuirkProbeIsDarkFill, middle);
  white = QuirkProbeMeasureIn (rep, QuirkProbeIsWhiteText, middle);
  rep = QuirkProbeRender (plain);
  plainDark = QuirkProbeMeasureIn (rep, QuirkProbeIsDarkFill,
                                   NSMakeRect (10, 6, [rep pixelsWide] - 20, [rep pixelsHigh] - 12));
  detail = [NSString stringWithFormat: @"custom: %lu dark and %lu white pixels of %ld; plain: %lu dark",
                     (unsigned long)dark.count, (unsigned long)white.count,
                     (long)(NSWidth (middle) * NSHeight (middle)), (unsigned long)plainDark.count];
  if (dark.count > NSWidth (middle) * NSHeight (middle) / 2 && white.count > 20
    && plainDark.count < NSWidth (middle) * NSHeight (middle) / 4)
    {
      [self pass: @"text-field-custom-background" detail: detail];
    }
  else
    {
      [self fail: @"text-field-custom-background" detail: detail];
    }
  [window orderOut: nil];
}

/* Shortcut labels as GTK writes them (gtk_accelerator_get_label): Shift,
   Ctrl, Alt, then the key; an uppercase key equivalent means Shift (#41). */
- (void) checkShortcutLabels
{
  NSArray *cases = [NSArray arrayWithObjects:
    [NSArray arrayWithObjects: @"o", [NSNumber numberWithUnsignedInteger: NSCommandKeyMask], @"Ctrl+O", nil],
    [NSArray arrayWithObjects: @"O", [NSNumber numberWithUnsignedInteger: NSCommandKeyMask], @"Shift+Ctrl+O", nil],
    [NSArray arrayWithObjects: @"s", [NSNumber numberWithUnsignedInteger: NSCommandKeyMask | NSShiftKeyMask],
              @"Shift+Ctrl+S", nil],
    [NSArray arrayWithObjects: @"s",
              [NSNumber numberWithUnsignedInteger: NSCommandKeyMask | NSShiftKeyMask | NSAlternateKeyMask],
              @"Shift+Ctrl+Alt+S", nil],
    [NSArray arrayWithObjects: @"1", [NSNumber numberWithUnsignedInteger: NSCommandKeyMask], @"Ctrl+1", nil],
    [NSArray arrayWithObjects: @"?", [NSNumber numberWithUnsignedInteger: NSCommandKeyMask], @"Ctrl+?", nil],
    nil];
  NSMutableArray *wrong = [NSMutableArray array];
  NSEnumerator *e = [cases objectEnumerator];
  NSArray *c;

  while ((c = [e nextObject]) != nil)
    {
      NSMenuItem *item = AUTORELEASE ([[NSMenuItem alloc] initWithTitle: @"Item" action: NULL
                                                          keyEquivalent: [c objectAtIndex: 0]]);
      NSString *label;

      [item setKeyEquivalentModifierMask: [[c objectAtIndex: 1] unsignedIntegerValue]];
      label = [item respondsToSelector: @selector(gnomeThemeShortcutLabel)]
        ? [item performSelector: @selector(gnomeThemeShortcutLabel)] : nil;
      if ([label isEqualToString: [c objectAtIndex: 2]] == NO)
        {
          [wrong addObject: [NSString stringWithFormat: @"\"%@\" mask %@: %@, want %@", [c objectAtIndex: 0],
                                      [c objectAtIndex: 1], label, [c objectAtIndex: 2]]];
        }
    }
  if ([wrong count] == 0)
    {
      [self pass: @"menu-shortcut-labels" detail: nil];
    }
  else
    {
      [self fail: @"menu-shortcut-labels" detail: [wrong componentsJoinedByString: @"; "]];
    }
}

- (void) checkMenuSeparatorAndShortcut
{
  NSMenu *menu = AUTORELEASE ([[NSMenu alloc] initWithTitle: @"Probe"]);
  NSMenu *submenu = AUTORELEASE ([[NSMenu alloc] initWithTitle: @"More"]);
  NSWindow *window;
  NSMenuView *menuView;
  NSBitmapImageRep *rep;
  NSRect bounds, rects[4];
  NSInteger i, rows = 0, top;
  NSUInteger background, line = 0;
  CGFloat shortcutGap, chevronGap;
  QuirkProbeInk ink;
  NSString *detail;
  BOOL highContrast;
  long contrast;

  [[menu addItemWithTitle: @"Alpha" action: @selector(description) keyEquivalent: @"1"] setTarget: self];
  [menu addItem: [NSMenuItem separatorItem]];
  [[menu addItemWithTitle: @"Quit" action: @selector(description) keyEquivalent: @"q"] setTarget: self];
  [menu setSubmenu: submenu forItem: [menu addItemWithTitle: @"More" action: NULL keyEquivalent: @""]];
  [submenu addItemWithTitle: @"Inner" action: NULL keyEquivalent: @""];
  menuView = AUTORELEASE ([[NSMenuView alloc] initWithFrame: NSMakeRect (0, 0, 200, 100)]);
  [menuView setMenu: menu];
  [menuView sizeToFit];
  window = [self windowWithFrame: NSMakeRect (40, 200, NSWidth ([menuView frame]) + 40, NSHeight ([menuView frame]) + 40)
                           title: @"QuirkProbe Menu"];
  [menuView setFrameOrigin: NSMakePoint (20, 20)];
  [[window contentView] addSubview: menuView];
  [window orderFront: nil];
  [window display];
  rep = QuirkProbeRender (menuView);
  bounds = [menuView bounds];
  for (i = 0; i < 4; i++)
    {
      rects[i] = [menuView rectOfItemAtIndex: i];
      if ([menuView isFlipped] == NO)
        {
          rects[i].origin.y = NSHeight (bounds) - NSMaxY (rects[i]);
        }
    }
  /* The separator: the rows in the middle of its cell that differ from
     the menu's background. */
  background = QuirkProbeMeasureIn (rep, QuirkProbeIsAnyPixel,
                                    NSMakeRect (NSMidX (rects[1]), NSMinY (rects[1]), 1, 1)).darkest;
  for (top = (NSInteger)NSMinY (rects[1]); top < (NSInteger)NSMaxY (rects[1]); top++)
    {
      NSUInteger value = QuirkProbeMeasureIn (rep, QuirkProbeIsAnyPixel,
                                              NSMakeRect (NSMidX (rects[1]), top, 1, 1)).darkest;

      if (labs ((long)value - (long)background) > 6)
        {
          rows++;
          if (labs ((long)value - (long)background) > labs ((long)line - (long)background) || line == 0)
            {
              line = value;
            }
        }
    }
  QuirkProbeInkBackground = background;
  /* In the middle of the rows, clear of the menu's rounded corners. */
  ink = QuirkProbeMeasureIn (rep, QuirkProbeIsInk,
                             NSMakeRect (NSMidX (bounds), NSMinY (rects[0]) + NSHeight (rects[0]) / 4.0,
                                         NSMaxX (rects[0]) - 2.0 - NSMidX (bounds), NSHeight (rects[0]) / 2.0));
  shortcutGap = NSMaxX (rects[0]) - (ink.minX + ink.width);
  {
    /* The chevron is drawn at 30%: anything clearly off the background. */
    NSInteger x, y, maxX = -1;
    NSUInteger pixel[5];

    for (y = (NSInteger)(NSMinY (rects[3]) + NSHeight (rects[3]) / 4.0);
         y < (NSInteger)(NSMaxY (rects[3]) - NSHeight (rects[3]) / 4.0); y++)
      {
        for (x = (NSInteger)NSMidX (bounds); x < (NSInteger)NSMaxX (rects[3]) - 2; x++)
          {
            NSUInteger sum;

            [rep getPixel: pixel atX: x y: y];
            sum = pixel[0] + pixel[1] + pixel[2];
            if (labs ((long)sum - (long)background) > 60)
              {
                maxX = MAX (maxX, x);
              }
          }
      }
    chevronGap = NSMaxX (rects[3]) - (maxX + 1);
  }
  [self saveWindow: window named: @"menu"];
  [window orderOut: nil];

  detail = [NSString stringWithFormat: @"separator %ld row(s), r+g+b %lu on %lu; shortcut ends %gpt, chevron %gpt "
    @"from the row's right edge (row %@)", (long)rows, (unsigned long)line, (unsigned long)background,
    shortcutGap, chevronGap, NSStringFromRect (rects[0])];
  /* Light: libadwaita's #e0e0e1 on white is 93 below it (15%). High
     contrast is 50%: half the text's contrast with the menu (about 380 in
     the light palette, 290 in the dark). The shortcut's box ends 16pt
     in, its ink a side bearing further; the arrow's 16pt box ends there
     too, its glyph centred in it. */
  highContrast = [[NSUserDefaults standardUserDefaults] boolForKey: @"ProbeHighContrast"];
  contrast = labs ((long)line - (long)background);
  if (rows == 1 && (highContrast ? (contrast >= 260 && contrast <= 460) : (contrast >= 50 && contrast <= 140))
    && shortcutGap >= 16 && shortcutGap <= 20 && chevronGap >= 18 && chevronGap <= 26)
    {
      [self pass: @"menu-separator-and-shortcut" detail: detail];
    }
  else
    {
      [self fail: @"menu-separator-and-shortcut" detail: detail];
    }
}

/* With GnomeThemeHeaderBarToolbar a window's toolbar is in its header bar
   row, as a GNOME app packs its buttons there: no row of its own (the
   content keeps its size), the title in the flexible space, presses on the
   bar's empty parts the bar's, icons without labels and an item without an
   icon a text button. */
/* The theme's answer: the toolbar view's superview holds it in the bar. */
static BOOL
GnomeThemeProbeToolbarInBar(NSToolbar *toolbar)
{
  NSView *superview = [[toolbar _toolbarView] superview];

  return [superview respondsToSelector: @selector(holdsToolbarInBar)]
    && [superview holdsToolbarInBar];
}

/* The header bar toolbar setting applies to open windows: turned off, the
   toolbar moves to a row of its own, and back into the bar when turned on,
   the window keeping its frame (plugins-themes-Adwaita#30). */
- (void) checkHeaderBarToolbarLive
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  QuirkProbeHeaderToolbarDelegate *delegate;
  NSWindow *window;
  NSToolbar *toolbar;
  NSView *frameView;
  NSRect frame, rowFrame, barFrame;
  BOOL inBar, inRow, backInBar;
  NSString *detail;

  if (QuirkProbeDrawsDecorations () == NO
    || [[defaults searchList] containsObject: @"QuirkProbeHeaderBarToolbar"] == NO)
    {
      [self skip: @"header-bar-toolbar-live" detail: @"needs -GSX11HandlesWindowDecorations NO"];
      return;
    }
  delegate = AUTORELEASE ([QuirkProbeHeaderToolbarDelegate new]);
  window = [self windowWithFrame: NSMakeRect (40, 200, 600, 200) title: @"Probe Toolbar Live"];
  toolbar = AUTORELEASE ([[NSToolbar alloc] initWithIdentifier: @"QuirkProbeLiveToolbar"]);
  [toolbar setDelegate: delegate];
  [window setToolbar: toolbar];
  [window orderFront: nil];
  frameView = [[window contentView] superview];
  frame = [window frame];
  inBar = GnomeThemeProbeToolbarInBar (toolbar);

  [defaults removeVolatileDomainForName: @"QuirkProbeHeaderBarToolbar"];
  [defaults setVolatileDomain: [NSDictionary dictionaryWithObject: @"NO" forKey: @"GnomeThemeHeaderBarToolbar"]
                      forName: @"QuirkProbeHeaderBarToolbar"];
  [[NSNotificationCenter defaultCenter] postNotificationName: NSUserDefaultsDidChangeNotification object: defaults];
  rowFrame = [window frame];
  inRow = GnomeThemeProbeToolbarInBar (toolbar) == NO && [[toolbar _toolbarView] superview] == frameView;

  [defaults removeVolatileDomainForName: @"QuirkProbeHeaderBarToolbar"];
  [defaults setVolatileDomain: [NSDictionary dictionaryWithObject: @"YES" forKey: @"GnomeThemeHeaderBarToolbar"]
                      forName: @"QuirkProbeHeaderBarToolbar"];
  [[NSNotificationCenter defaultCenter] postNotificationName: NSUserDefaultsDidChangeNotification object: defaults];
  barFrame = [window frame];
  backInBar = GnomeThemeProbeToolbarInBar (toolbar);
  [window orderOut: nil];
  [window setToolbar: nil];
  /* Toolbars don't retain their delegates. */
  [toolbar setDelegate: nil];

  detail = [NSString stringWithFormat: @"%@; turned off: %@, frame %@; turned on: %@, frame %@ (was %@)",
    inBar ? @"in the bar" : @"not in the bar", inRow ? @"a row of its own" : @"not moved",
    NSStringFromRect (rowFrame), backInBar ? @"in the bar" : @"not moved", NSStringFromRect (barFrame),
    NSStringFromRect (frame)];
  if (inBar && inRow && backInBar && NSEqualRects (rowFrame, frame) && NSEqualRects (barFrame, frame))
    {
      [self pass: @"header-bar-toolbar-live" detail: detail];
    }
  else
    {
      [self fail: @"header-bar-toolbar-live" detail: detail];
    }
}

/* The title ink in a header bar window, between the bar's left border
   and its buttons. */
static QuirkProbeInk
QuirkProbeHeaderTitleInk(NSWindow *window)
{
  NSView *frameView = [[window contentView] superview];
  NSBitmapImageRep *rep;

  [window display];
  rep = QuirkProbeRender (frameView);
  QuirkProbeInkBackground = QuirkProbeMeasureIn (rep, QuirkProbeIsAnyPixel, NSMakeRect (20, 4, 4, 4)).darkest;
  return QuirkProbeMeasureIn (rep, QuirkProbeIsInk, NSMakeRect (1, 1, NSWidth ([frameView bounds]) - 130, 44));
}

/* A document window's header bar shows the file's name, not GNUstep's
   "name  --  ~/folder", with the folder on hover, as GNOME's
   AdwWindowTitle (plugins-themes-Adwaita#31), and a dot before it while
   the document has unsaved changes (#39). */
- (void) checkHeaderBarDocumentTitle
{
  NSWindow *window;
  NSView *frameView;
  QuirkProbeInk document, plain, edited, saved;
  NSString *folder = nil;
  NSString *detail;

  if (QuirkProbeDrawsDecorations () == NO)
    {
      [self skip: @"header-bar-document-title" detail: @"needs -GSX11HandlesWindowDecorations NO"];
      return;
    }
  window = [self windowWithFrame: NSMakeRect (60, 300, 500, 150) title: @"Probe Document"];
  [window setTitleWithRepresentedFilename: @"/tmp/Probe Folder/white.png"];
  [window makeKeyAndOrderFront: nil];
  frameView = [[window contentView] superview];
  document = QuirkProbeHeaderTitleInk (window);
  if ([frameView respondsToSelector: @selector(view:stringForToolTip:point:userData:)])
    {
      /* A copy: retitling the window below lets the bar's go. */
      folder = AUTORELEASE ([[(id)frameView view: frameView stringForToolTip: 0 point: NSZeroPoint userData: NULL]
                              copy]);
    }
  [window setTitle: @"white.png"];
  plain = QuirkProbeHeaderTitleInk (window);
  /* Unsaved changes: a dot before the title, gone once saved
     (plugins-themes-Adwaita#39). */
  [window setDocumentEdited: YES];
  edited = QuirkProbeHeaderTitleInk (window);
  [window setDocumentEdited: NO];
  saved = QuirkProbeHeaderTitleInk (window);
  [window orderOut: nil];
  detail = [NSString stringWithFormat: @"title \"%@\" drawn %ldpx wide (\"white.png\" alone %ldpx); "
    @"folder on hover \"%@\"; edited %ldpx, saved again %ldpx", @"white.png  --  /tmp/Probe Folder",
    (long)document.width, (long)plain.width, folder ?: @"(none)", (long)edited.width, (long)saved.width];
  if (document.count > 0 && labs ((long)document.width - (long)plain.width) <= 1
    && [folder isEqualToString: @"/tmp/Probe Folder"]
    && edited.width >= plain.width + 6 && labs ((long)saved.width - (long)plain.width) <= 1)
    {
      [self pass: @"header-bar-document-title" detail: detail];
    }
  else
    {
      [self fail: @"header-bar-document-title" detail: detail];
    }
}

/* With the toolbar in the header bar, a press on an item's empty part (a
   container) or a label drags the window, as a GTK header bar's does: only
   controls keep their presses (plugins-themes-Adwaita#36). */
- (void) checkHeaderBarToolbarItemDrag
{
  QuirkProbeDragToolbarDelegate *delegate;
  NSWindow *window;
  NSToolbar *toolbar;
  NSView *frameView, *labelHit;
  NSRect boxFrame, labelFrame, before, after;
  NSPoint start;
  NSString *detail;
  int i;

  if (QuirkProbeDrawsDecorations () == NO
    || [[[NSUserDefaults standardUserDefaults] searchList] containsObject: @"QuirkProbeHeaderBarToolbar"] == NO)
    {
      [self skip: @"header-bar-toolbar-item-drag" detail: @"needs -GSX11HandlesWindowDecorations NO"];
      return;
    }
  delegate = AUTORELEASE ([QuirkProbeDragToolbarDelegate new]);
  window = [self windowWithFrame: NSMakeRect (200, 200, 500, 200) title: @"Probe Toolbar Drag"];
  toolbar = AUTORELEASE ([[NSToolbar alloc] initWithIdentifier: @"QuirkProbeDragToolbar"]);
  [toolbar setDelegate: delegate];
  [window setToolbar: toolbar];
  [window makeKeyAndOrderFront: nil];
  [window display];
  frameView = [[window contentView] superview];
  labelFrame = [delegate->label convertRect: [delegate->label bounds] toView: nil];
  labelHit = [frameView hitTest: NSMakePoint (NSMidX (labelFrame), NSMidY (labelFrame))];

  /* A press on the box, dragged 40px right, released. (The bar's own
     move, with no window manager to hand it to, follows the real pointer,
     so the window can move further: a move is what's checked.) */
  boxFrame = [delegate->box convertRect: [delegate->box bounds] toView: nil];
  start = NSMakePoint (NSMidX (boxFrame), NSMidY (boxFrame));
  before = [window frame];
  for (i = 1; i <= 4; i++)
    {
      [NSApp postEvent: [NSEvent mouseEventWithType: NSLeftMouseDragged
                                           location: NSMakePoint (start.x + 10 * i, start.y)
                                      modifierFlags: 0 timestamp: 0 windowNumber: [window windowNumber]
                                            context: nil eventNumber: 0 clickCount: 1 pressure: 1.0]
               atStart: NO];
    }
  [NSApp postEvent: [NSEvent mouseEventWithType: NSLeftMouseUp location: NSMakePoint (start.x + 40, start.y)
                                  modifierFlags: 0 timestamp: 0 windowNumber: [window windowNumber]
                                        context: nil eventNumber: 0 clickCount: 1 pressure: 0.0]
           atStart: NO];
  [window sendEvent: [NSEvent mouseEventWithType: NSLeftMouseDown location: start modifierFlags: 0
                                        timestamp: 0 windowNumber: [window windowNumber] context: nil
                                      eventNumber: 0 clickCount: 1 pressure: 1.0]];
  after = [window frame];
  [window orderOut: nil];
  [window setToolbar: nil];
  [toolbar setDelegate: nil];

  detail = [NSString stringWithFormat: @"a press on the label goes to %@; a drag from the box moved the window %@ -> %@",
    NSStringFromClass ([labelHit class]), NSStringFromPoint (before.origin), NSStringFromPoint (after.origin)];
  if (labelHit == frameView && NSMinX (after) - NSMinX (before) >= 20)
    {
      [self pass: @"header-bar-toolbar-item-drag" detail: detail];
    }
  else
    {
      [self fail: @"header-bar-toolbar-item-drag" detail: detail];
    }
}

/* With the toolbar in the header bar, a click on an item's view that
   handles only the release reaches it: the press it passes on isn't the
   bar's to drag, and the bar leaves the release alone
   (plugins-themes-Adwaita#33). */
- (void) checkHeaderBarToolbarItemClick
{
  QuirkProbeReleaseToolbarDelegate *delegate;
  NSWindow *window;
  NSToolbar *toolbar;
  NSRect frame;
  NSPoint point;
  NSEvent *down, *up, *pending;
  NSView *hit;
  NSString *detail;
  BOOL inBar;

  if (QuirkProbeDrawsDecorations () == NO)
    {
      [self skip: @"header-bar-toolbar-item-click" detail: @"needs -GSX11HandlesWindowDecorations NO"];
      return;
    }
  /* The app opting in (as -checkHeaderBarToolbar does). */
  if ([[[NSUserDefaults standardUserDefaults] searchList] containsObject: @"QuirkProbeHeaderBarToolbar"] == NO)
    {
      NSMutableArray *searchList = AUTORELEASE ([[[NSUserDefaults standardUserDefaults] searchList] mutableCopy]);

      [[NSUserDefaults standardUserDefaults]
        setVolatileDomain: [NSDictionary dictionaryWithObject: @"YES" forKey: @"GnomeThemeHeaderBarToolbar"]
                  forName: @"QuirkProbeHeaderBarToolbar"];
      [searchList insertObject: @"QuirkProbeHeaderBarToolbar" atIndex: 0];
      [[NSUserDefaults standardUserDefaults] setSearchList: searchList];
    }
  delegate = AUTORELEASE ([QuirkProbeReleaseToolbarDelegate new]);
  window = [self windowWithFrame: NSMakeRect (40, 200, 500, 200) title: @"Probe Toolbar Click"];
  toolbar = AUTORELEASE ([[NSToolbar alloc] initWithIdentifier: @"QuirkProbeReleaseToolbar"]);
  [toolbar setDelegate: delegate];
  [window setToolbar: toolbar];
  /* Key, as the window being used: a first click on another window only
     activates it. */
  [window makeKeyAndOrderFront: nil];
  [window display];
  inBar = [[[toolbar _toolbarView] superview] isEqual: [[window contentView] superview]];
  frame = [delegate->view convertRect: [delegate->view bounds] toView: nil];
  point = NSMakePoint (NSMidX (frame), NSMidY (frame));
  hit = [[[window contentView] superview] hitTest: point];
  if (hit != delegate->view)
    {
      [self fail: @"header-bar-toolbar-item-click"
          detail: [NSString stringWithFormat: @"the item's view at %@ in the window; a press there goes to %@",
                            NSStringFromRect (frame), NSStringFromClass ([hit class])]];
      [window orderOut: nil];
      [window setToolbar: nil];
      [toolbar setDelegate: nil];
      return;
    }
  down = [NSEvent mouseEventWithType: NSLeftMouseDown location: point modifierFlags: 0
                           timestamp: 0 windowNumber: [window windowNumber] context: nil
                         eventNumber: 0 clickCount: 1 pressure: 1.0];
  up = [NSEvent mouseEventWithType: NSLeftMouseUp location: point modifierFlags: 0
                         timestamp: 0 windowNumber: [window windowNumber] context: nil
                       eventNumber: 0 clickCount: 1 pressure: 0.0];
  /* Queued first: a bar that reads up to the release finds it, rather
     than waiting for it. */
  [NSApp postEvent: up atStart: NO];
  [window sendEvent: down];
  pending = [NSApp nextEventMatchingMask: NSLeftMouseUpMask untilDate: [NSDate distantPast]
                                  inMode: NSDefaultRunLoopMode dequeue: YES];
  if (pending != nil)
    {
      [window sendEvent: pending];
    }
  detail = [NSString stringWithFormat: @"toolbar %@ the bar; the item's view saw %d release(s) "
    @"(the release was %@)", inBar ? @"in" : @"not in", delegate->view->releases,
    pending != nil ? @"left for it" : @"taken by the bar"];
  if (inBar && delegate->view->releases == 1)
    {
      [self pass: @"header-bar-toolbar-item-click" detail: detail];
    }
  else
    {
      [self fail: @"header-bar-toolbar-item-click" detail: detail];
    }
  [window orderOut: nil];
  [window setToolbar: nil];
  /* Toolbars don't retain their delegates. */
  [toolbar setDelegate: nil];
}

- (void) checkHeaderBarToolbar
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSMutableArray *searchList;
  QuirkProbeHeaderToolbarDelegate *delegate;
  NSWindow *window;
  NSToolbar *toolbar;
  NSView *frameView, *toolbarView, *hitGap = nil, *hitIcon = nil;
  NSSize before, after;
  NSRect bounds, gap = NSZeroRect, iconFrame = NSZeroRect;
  NSBitmapImageRep *rep;
  QuirkProbeInk title;
  NSMutableArray *positions = [NSMutableArray array];
  NSEnumerator *enumerator;
  NSToolbarItem *item;
  BOOL labelsOk = YES;
  NSString *detail;

  if (QuirkProbeDrawsDecorations () == NO)
    {
      [self skip: @"header-bar-toolbar" detail: @"needs -GSX11HandlesWindowDecorations NO"];
      return;
    }
  /* The app opting in, in a domain of its own: nothing saved. */
  [defaults setVolatileDomain: [NSDictionary dictionaryWithObject: @"YES" forKey: @"GnomeThemeHeaderBarToolbar"]
                      forName: @"QuirkProbeHeaderBarToolbar"];
  searchList = AUTORELEASE ([[defaults searchList] mutableCopy]);
  [searchList insertObject: @"QuirkProbeHeaderBarToolbar" atIndex: 0];
  [defaults setSearchList: searchList];

  delegate = [QuirkProbeHeaderToolbarDelegate new];
  window = [self windowWithFrame: NSMakeRect (40, 200, 700, 260) title: @"Probe Toolbar Bar"];
  before = [[window contentView] frame].size;
  toolbar = AUTORELEASE ([[NSToolbar alloc] initWithIdentifier: @"QuirkProbeHeaderToolbar"]);
  [toolbar setDelegate: delegate];
  [window setToolbar: toolbar];
  [window orderFront: nil];
  [window display];
  after = [[window contentView] frame].size;
  frameView = [[window contentView] superview];
  bounds = [frameView bounds];
  toolbarView = [toolbar _toolbarView];

  enumerator = [[toolbar items] objectEnumerator];
  while ((item = [enumerator nextObject]) != nil)
    {
      NSView *backView = [item _backView];
      NSRect frame = [frameView convertRect: [backView bounds] fromView: backView];

      [positions addObject: [NSString stringWithFormat: @"%@ %g-%g", [item itemIdentifier], NSMinX (frame), NSMaxX (frame)]];
      if ([[item itemIdentifier] isEqualToString: NSToolbarFlexibleSpaceItemIdentifier])
        {
          gap = frame;
        }
      else if ([backView isKindOfClass: [NSButton class]])
        {
          NSCellImagePosition position = [(NSButton *)backView imagePosition];

          labelsOk = labelsOk && position == ([item image] != nil ? NSImageOnly : NSNoImage);
          if ([[item itemIdentifier] isEqualToString: @"IconA"])
            {
              iconFrame = frame;
            }
        }
    }
  if (NSIsEmptyRect (gap) == NO)
    {
      hitGap = [frameView hitTest: NSMakePoint (NSMidX (gap) - 1, NSMidY (gap))];
    }
  if (NSIsEmptyRect (iconFrame) == NO)
    {
      hitIcon = [frameView hitTest: NSMakePoint (NSMidX (iconFrame), NSMidY (iconFrame))];
    }
  rep = QuirkProbeRender (frameView);
  /* The title's ink in the bar, in pixels from the top left, below the
     window's border: anything clearly off the bar's background, in any
     palette (dimmed: the probe's window isn't the key window; nothing
     else is in the gap). */
  QuirkProbeInkBackground = QuirkProbeMeasureIn (rep, QuirkProbeIsAnyPixel,
                                                 NSMakeRect (NSMinX (gap) + 2, 4, 1, 1)).darkest;
  title = QuirkProbeMeasureIn (rep, QuirkProbeIsInk,
                               NSMakeRect (NSMinX (gap), 2, NSWidth (gap), 42));
  [self saveWindow: window named: @"header-bar-toolbar"];
  [window orderOut: nil];

  /* Too narrow for the toolbar: the items that don't fit go into libs-gui's
     » menu, a button inside the bar at the end of the toolbar. */
  {
    NSWindow *narrow = [self windowWithFrame: NSMakeRect (40, 200, 150, 200) title: @"Probe Toolbar Narrow"];
    NSToolbar *narrowToolbar = AUTORELEASE ([[NSToolbar alloc] initWithIdentifier: @"QuirkProbeHeaderToolbarNarrow"]);
    NSView *narrowFrame, *narrowToolbarView, *mark = nil;
    NSRect markFrame = NSZeroRect;
    NSString *narrowDetail;

    [narrowToolbar setDelegate: delegate];
    [narrow setToolbar: narrowToolbar];
    [narrow orderFront: nil];
    [narrow display];
    narrowFrame = [[narrow contentView] superview];
    narrowToolbarView = [narrowToolbar _toolbarView];
    enumerator = [[narrowToolbarView subviews] objectEnumerator];
    while ((mark = [enumerator nextObject]) != nil)
      {
        if ([mark isKindOfClass: [NSButton class]])
          {
            markFrame = [narrowFrame convertRect: [mark bounds] fromView: mark];
            break;
          }
      }
    [narrow orderOut: nil];
    narrowDetail = [NSString stringWithFormat: @"toolbar %@, » %@ in %@",
      NSStringFromRect ([narrowToolbarView frame]), NSStringFromRect (markFrame),
      NSStringFromRect ([narrowFrame bounds])];
    if (mark != nil && NSMinY (markFrame) >= NSMaxY ([narrowFrame bounds]) - 46.5
      && NSMaxY (markFrame) <= NSMaxY ([narrowFrame bounds]) + 0.5
      && NSMaxX (markFrame) <= NSMaxX ([narrowToolbarView frame]) + 0.5)
      {
        [self pass: @"header-bar-toolbar-overflow" detail: narrowDetail];
      }
    else
      {
        [self fail: @"header-bar-toolbar-overflow" detail: narrowDetail];
      }
  }

  /* Right to left, as GTK mirrors its header bar: the first item at the
     right end, the items after the flexible space at the left. */
  {
    NSWindow *mirrored;
    NSToolbar *mirroredToolbar = AUTORELEASE ([[NSToolbar alloc] initWithIdentifier: @"QuirkProbeHeaderToolbarRTL"]);
    NSRect first = NSZeroRect, last = NSZeroRect, space = NSZeroRect;
    NSView *mirroredFrame;
    NSString *mirroredDetail;

    [defaults removeVolatileDomainForName: @"QuirkProbeHeaderBarToolbar"];
    [defaults setVolatileDomain: [NSDictionary dictionaryWithObjectsAndKeys:
                                                 @"YES", @"GnomeThemeHeaderBarToolbar",
                                                 @"YES", @"NSForceRightToLeftWritingDirection", nil]
                        forName: @"QuirkProbeHeaderBarToolbar"];
    mirrored = [self windowWithFrame: NSMakeRect (40, 200, 700, 200) title: @"Probe Toolbar RTL"];
    [mirroredToolbar setDelegate: delegate];
    [mirrored setToolbar: mirroredToolbar];
    [mirrored orderFront: nil];
    [mirrored display];
    mirroredFrame = [[mirrored contentView] superview];
    enumerator = [[mirroredToolbar items] objectEnumerator];
    while ((item = [enumerator nextObject]) != nil)
      {
        NSView *backView = [item _backView];
        NSRect frame = [mirroredFrame convertRect: [backView bounds] fromView: backView];

        if ([[item itemIdentifier] isEqualToString: @"IconA"])
          first = frame;
        else if ([[item itemIdentifier] isEqualToString: @"IconC"])
          last = frame;
        else if ([[item itemIdentifier] isEqualToString: NSToolbarFlexibleSpaceItemIdentifier])
          space = frame;
      }
    [mirrored orderOut: nil];
    mirroredDetail = [NSString stringWithFormat: @"IconA %g-%g, flexible space %g-%g, IconC %g-%g in %g",
      NSMinX (first), NSMaxX (first), NSMinX (space), NSMaxX (space), NSMinX (last), NSMaxX (last),
      NSWidth ([mirroredFrame bounds])];
    if (NSMinX (first) > NSMaxX (space) && NSMaxX (last) < NSMinX (space)
      && NSMaxX (first) > NSWidth ([mirroredFrame bounds]) - 60)
      {
        [self pass: @"header-bar-toolbar-rtl" detail: mirroredDetail];
      }
    else
      {
        [self fail: @"header-bar-toolbar-rtl" detail: mirroredDetail];
      }
  }

  [searchList removeObject: @"QuirkProbeHeaderBarToolbar"];
  [defaults setSearchList: searchList];
  [defaults removeVolatileDomainForName: @"QuirkProbeHeaderBarToolbar"];

  detail = [NSString stringWithFormat: @"content %@ -> %@; toolbar %@ in %@; items %@; title ink x %ld-%ld in the gap; "
    @"a press in the gap goes to %@, on an icon to %@; labels %@",
    NSStringFromSize (before), NSStringFromSize (after), NSStringFromRect ([toolbarView frame]),
    NSStringFromRect (bounds), [positions componentsJoinedByString: @", "],
    (long)title.minX, (long)(title.minX + title.width), NSStringFromClass ([hitGap class]),
    NSStringFromClass ([hitIcon class]), labelsOk ? @"as expected" : @"wrong"];
  if (NSEqualSizes (before, after) && [toolbarView superview] == frameView
    && NSMinY ([toolbarView frame]) >= NSMaxY (bounds) - 46.5 && NSHeight ([toolbarView frame]) == 46
    && title.count > 0 && title.minX > NSMinX (gap) && title.minX + title.width < NSMaxX (gap)
    && hitGap == frameView && [hitIcon respondsToSelector: @selector(toolbarItem)] && labelsOk)
    {
      [self pass: @"header-bar-toolbar" detail: detail];
    }
  else
    {
      [self fail: @"header-bar-toolbar" detail: detail];
    }
}

/* A selected segment stands out from the others, further from the window's
   background, in any palette (plugins-themes-Adwaita#7: in the dark one it
   was 2/255 darker than the others). Runs with the dark and high contrast
   header bar runs too. */
- (void) checkSegmentedSelection
{
  NSWindow *window = [self windowWithFrame: NSMakeRect (40, 200, 300, 80) title: @"QuirkProbe Segments"];
  NSSegmentedControl *control = AUTORELEASE ([[NSSegmentedControl alloc] initWithFrame: NSMakeRect (20, 20, 240, 34)]);
  NSBitmapImageRep *rep, *windowRep;
  NSUInteger fills[2], background;
  NSInteger i;
  NSString *detail;

  [control setSegmentCount: 3];
  for (i = 0; i < 3; i++)
    {
      [control setLabel: [NSString stringWithFormat: @"Item %ld", (long)i + 1] forSegment: i];
      [control setWidth: 80 forSegment: i];
    }
  [control setSelectedSegment: 1];
  [[window contentView] addSubview: control];
  [window orderFront: nil];
  [window display];
  rep = QuirkProbeRender (control);
  windowRep = QuirkProbeRender ([window contentView]);
  /* Inside each segment, near its top edge, clear of the label. */
  for (i = 0; i < 2; i++)
    {
      fills[i] = QuirkProbeMeasureIn (rep, QuirkProbeIsAnyPixel, NSMakeRect (40 + 80 * i, 4, 2, 2)).darkest;
    }
  background = QuirkProbeMeasureIn (windowRep, QuirkProbeIsAnyPixel, NSMakeRect (2, 2, 2, 2)).darkest;
  [self saveWindow: window named: @"segments"];
  [window orderOut: nil];

  detail = [NSString stringWithFormat: @"r+g+b: window %lu, unselected segment %lu, selected %lu",
    (unsigned long)background, (unsigned long)fills[0], (unsigned long)fills[1]];
  if (labs ((long)fills[1] - (long)fills[0]) >= 60
    && labs ((long)fills[1] - (long)background) > labs ((long)fills[0] - (long)background))
    {
      [self pass: @"segment-selected-visible" detail: detail];
    }
  else
    {
      [self fail: @"segment-selected-visible" detail: detail];
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

/* A pop-up button's chevron is libadwaita's pan-down: about 10x7 with a
   2px stroke, in the text colour, and nothing else at that end (GNUstep's
   was 6x4 and faint, after a divider; plugins-themes-Adwaita#59). */
- (void) checkPopUpChevron
{
  NSWindow *window = [self windowWithFrame: NSMakeRect (60, 60, 260, 70) title: @"Probe Chevron"];
  NSPopUpButton *popUp = AUTORELEASE ([[NSPopUpButton alloc] initWithFrame: NSMakeRect (20, 18, 200, 34)
                                                                pullsDown: NO]);
  NSBitmapImageRep *rep;
  NSUInteger fill[3];
  QuirkProbeInk ink;
  NSInteger width;
  NSString *detail;

  [popUp addItemWithTitle: @"x"];
  [[window contentView] addSubview: popUp];
  [window orderFront: nil];
  [window display];
  rep = QuirkProbeRender (popUp);
  width = [rep pixelsWide];
  QuirkProbePixelAt (rep, width - 6, [rep pixelsHigh] / 2, fill);
  QuirkProbeInkBackground = fill[0] + fill[1] + fill[2];
  /* Inside the bezel: in high contrast its 1px outline (#61) runs along the
     top, bottom and right edges and isn't the chevron. */
  ink = QuirkProbeMeasureIn (rep, QuirkProbeIsInk, NSMakeRect (width - 40, 4, 32, [rep pixelsHigh] - 8));
  QuirkProbeInkBackground = 750;
  [window orderOut: nil];

  detail = [NSString stringWithFormat: @"ink %ldx%ld at the right end (want about 10x7)", (long)ink.width, (long)ink.height];
  if (ink.count > 0 && ink.width >= 9 && ink.width <= 11 && ink.height >= 5 && ink.height <= 8)
    {
      [self pass: @"popup-chevron" detail: detail];
    }
  else
    {
      [self fail: @"popup-chevron" detail: detail];
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

/* The menu bar overflow check: actions run by a folded menu's key
   equivalent, and the items of the menu the overflow button showed. */
static NSUInteger QuirkProbeOverflowActions = 0;
static NSString *QuirkProbeOverflowShown = nil;

- (void) overflowAction: (id)sender
{
  QuirkProbeOverflowActions++;
}

/* Fires while the overflow button's menu tracks: note its items, then
   click elsewhere to close it. */
- (void) inspectOverflowMenu: (NSTimer *)timer
{
  NSEnumerator *enumerator = [[NSApp windows] objectEnumerator];
  NSWindow *window;

  ASSIGN (QuirkProbeOverflowShown, @"");
  while ((window = [enumerator nextObject]) != nil)
    {
      NSMenuView *menuView = (NSMenuView *)QuirkProbeFindViewOfClass ([window contentView], [NSMenuView class]);

      if ([window isVisible] && menuView != nil && [menuView isHorizontal] == NO)
        {
          NSMutableArray *titles = [NSMutableArray array];
          NSEnumerator *items = [[[menuView menu] itemArray] objectEnumerator];
          NSMenuItem *item;

          while ((item = [items nextObject]) != nil)
            {
              [titles addObject: [item title]];
            }
          ASSIGN (QuirkProbeOverflowShown, [titles componentsJoinedByString: @", "]);
        }
    }
  [GSCurrentServer () setMouseLocation: [_controlsWindow convertBaseToScreen: NSMakePoint (850, 20)]
                              onScreen: [[_controlsWindow screen] screenNumber]];
  [self after: 0.2 perform: @selector(clickOffMenuBar:) mode: NSEventTrackingRunLoopMode];
}

/* A window too narrow for its menu bar (#25): the titles that don't fit
   fold into an overflow button at the bar's end, ☰ stays first, a click on
   the button shows the folded menus, and their key equivalents still
   work. Widened again, the bar is as it was. */
- (void) checkMenuBarOverflow
{
  NSMenu *mainMenu = [NSApp mainMenu];
  NSString *name = [[NSProcessInfo processInfo] processName];
  NSMenu *appMenu = AUTORELEASE ([[NSMenu alloc] initWithTitle: name]);
  NSMenuItem *appItem = AUTORELEASE ([[NSMenuItem alloc] initWithTitle: name action: NULL keyEquivalent: @""]);
  NSArray *titles = [NSArray arrayWithObjects: @"Edit", @"View", @"Navigate", @"Window", @"Overflow Tools", nil];
  NSMutableArray *added = [NSMutableArray array];
  NSMutableArray *wideRects = [NSMutableArray array];
  NSMutableArray *folded = [NSMutableArray array];
  NSMutableArray *shownTitles = [NSMutableArray array];
  NSWindow *window;
  NSMenuView *menuView;
  NSRect frame = NSMakeRect (60, 60, 720, 120);
  NSRect overflow, wideOverflow, bounds, wideFrame;
  NSMenu *overflowMenu;
  NSEvent *key;
  NSUInteger i, count;
  NSUInteger actionsBefore = QuirkProbeOverflowActions;
  BOOL keyHandled;
  BOOL layoutOK = YES;
  BOOL submenusOK = YES;
  BOOL restored = YES;
  NSInteger hit;
  QuirkProbeInk ink;
  NSString *narrowDetail, *widenDetail;

  if (NSInterfaceStyleForKey (@"NSMenuInterfaceStyle", nil) != NSWindows95InterfaceStyle
    || [[[NSUserDefaults standardUserDefaults] stringForKey: @"GnomeThemeMenuStyle"] isEqualToString: @"primary"])
    {
      [self skip: @"menubar-overflow" detail: @"needs the menu bar (NSWindows95InterfaceStyle, not primary)"];
      [self skip: @"menubar-overflow-widens-back" detail: @"needs the menu bar (NSWindows95InterfaceStyle, not primary)"];
      [self skip: @"menubar-overflow-click" detail: @"needs the menu bar (NSWindows95InterfaceStyle, not primary)"];
      return;
    }
  if ([NSMenuView instancesRespondToSelector: @selector(gnomeThemeOverflowRect)] == NO)
    {
      [self fail: @"menubar-overflow" detail: @"the theme has no menu bar overflow"];
      return;
    }

  [appMenu addItemWithTitle: @"Info" action: NULL keyEquivalent: @""];
  [appItem setSubmenu: appMenu];
  [mainMenu insertItem: appItem atIndex: 0];
  for (i = 0; i < [titles count]; i++)
    {
      NSMenu *submenu = AUTORELEASE ([[NSMenu alloc] initWithTitle: [titles objectAtIndex: i]]);
      NSMenuItem *item = (NSMenuItem *)[mainMenu addItemWithTitle: [titles objectAtIndex: i]
                                                           action: NULL
                                                    keyEquivalent: @""];

      if (i == [titles count] - 1)
        {
          [[submenu addItemWithTitle: @"Overflow Action" action: @selector(overflowAction:) keyEquivalent: @"j"]
            setTarget: self];
        }
      else
        {
          [submenu addItemWithTitle: @"Item" action: NULL keyEquivalent: @""];
        }
      [mainMenu setSubmenu: submenu forItem: item];
      [added addObject: item];
    }

  window = [self windowWithFrame: frame title: @"Menu Bar Overflow"];
  if ([window menu] == nil)
    {
      [[GSTheme theme] setMenu: mainMenu forWindow: window];
    }
  [window orderFront: nil];
  menuView = (NSMenuView *)QuirkProbeFindViewOfClass ([[window contentView] superview], [NSMenuView class]);
  if (menuView == nil || [menuView isHorizontal] == NO)
    {
      [self fail: @"menubar-overflow" detail: @"no menu bar in the window"];
      [window orderOut: nil];
      [mainMenu removeItem: appItem];
      for (i = 0; i < [added count]; i++)
        {
          [mainMenu removeItem: [added objectAtIndex: i]];
        }
      return;
    }
  [menuView sizeToFit];
  [window display];
  count = [mainMenu numberOfItems];
  for (i = 0; i < count; i++)
    {
      [wideRects addObject: NSStringFromRect ([menuView rectOfItemAtIndex: i])];
    }
  wideOverflow = [menuView gnomeThemeOverflowRect];
  wideFrame = [window frame];
  [self saveWindow: window named: @"menubar-overflow-wide"];

  /* Narrow: ☰, then the titles that fit, then the button. */
  [window setFrame: NSMakeRect (NSMinX ([window frame]), NSMinY ([window frame]), 240, NSHeight ([window frame]))
           display: YES];
  bounds = [menuView bounds];
  overflow = [menuView gnomeThemeOverflowRect];
  for (i = 0; i < count; i++)
    {
      NSRect rect = [menuView rectOfItemAtIndex: i];

      if (NSWidth (rect) == 0.0)
        {
          [folded addObject: [[mainMenu itemAtIndex: i] title]];
        }
      else if ([folded count] > 0 || NSMaxX (rect) > NSMinX (overflow) || NSMinX (rect) < NSMinX (bounds))
        {
          /* A shown title after a folded one, or one reaching the button. */
          layoutOK = NO;
        }
    }
  overflowMenu = [menuView gnomeThemeOverflowMenu];
  for (i = 0; i < (NSUInteger)[overflowMenu numberOfItems]; i++)
    {
      NSMenuItem *item = (NSMenuItem *)[overflowMenu itemAtIndex: i];

      [shownTitles addObject: [item title]];
      if ([item hasSubmenu] == NO || [[item submenu] numberOfItems] == 0)
        {
          submenusOK = NO;
        }
    }
  hit = [menuView indexOfItemAtPoint: NSMakePoint (NSMidX (overflow), NSMidY (overflow))];
  [window display];
  {
    NSBitmapImageRep *rep = QuirkProbeRender (menuView);
    CGFloat scale = [rep pixelsWide] / NSWidth (bounds);
    NSRect area = NSMakeRect (NSMinX (overflow) * scale,
                              ([menuView isFlipped] ? NSMinY (overflow) : NSHeight (bounds) - NSMaxY (overflow)) * scale,
                              NSWidth (overflow) * scale, NSHeight (overflow) * scale);

    ink = QuirkProbeMeasureIn (rep, QuirkProbeIsTextInk, area);
  }
  key = [NSEvent keyEventWithType: NSKeyDown
                         location: NSZeroPoint
                    modifierFlags: NSCommandKeyMask
                        timestamp: 0
                     windowNumber: [window windowNumber]
                          context: nil
                       characters: @"j"
      charactersIgnoringModifiers: @"j"
                        isARepeat: NO
                          keyCode: 0];
  keyHandled = [mainMenu performKeyEquivalent: key];
  [self saveWindow: window named: @"menubar-overflow-narrow"];

  narrowDetail = [NSString stringWithFormat: @"bar %gpt wide: ☰ at x %g, overflow button at x %g-%g (ink %lu px), "
    @"folded: %@, its menu: %@, a click on it hits item %ld, the folded Overflow Tools' Cmd-J %@ (%lu action)",
    NSWidth (bounds), NSMinX ([menuView rectOfItemAtIndex: 0]), NSMinX (overflow), NSMaxX (overflow),
    (unsigned long)ink.count, [folded componentsJoinedByString: @", "], [shownTitles componentsJoinedByString: @", "],
    (long)hit, keyHandled ? @"handled" : @"not handled",
    (unsigned long)(QuirkProbeOverflowActions - actionsBefore)];
  if (NSIsEmptyRect (wideOverflow) && NSIsEmptyRect (overflow) == NO && NSMaxX (overflow) <= NSMaxX (bounds)
    && layoutOK && submenusOK && [folded count] > 0 && [folded isEqualToArray: shownTitles]
    && [folded containsObject: name] == NO && NSMinX ([menuView rectOfItemAtIndex: 0]) < 20
    && hit == -1 && ink.count > 0 && keyHandled && QuirkProbeOverflowActions == actionsBefore + 1)
    {
      [self pass: @"menubar-overflow" detail: narrowDetail];
    }
  else
    {
      [self fail: @"menubar-overflow" detail: narrowDetail];
    }

  /* A click on the button shows the folded menus; a click elsewhere
     closes them. Moves the pointer, so only on the probe's own display. */
  if ([[NSUserDefaults standardUserDefaults] boolForKey: @"ProbeOwnsDisplay"] == NO)
    {
      [self skip: @"menubar-overflow-click" detail: @"moves the pointer: only on the probe's own Xvfb"];
    }
  else
    {
      NSRect button = [menuView convertRect: overflow toView: nil];
      NSPoint point = NSMakePoint (NSMidX (button), NSMidY (button));
      NSEvent *down = [NSEvent mouseEventWithType: NSLeftMouseDown location: point modifierFlags: 0
                                        timestamp: 0 windowNumber: [window windowNumber] context: nil
                                      eventNumber: 0 clickCount: 1 pressure: 1];
      NSEvent *up = [NSEvent mouseEventWithType: NSLeftMouseUp location: point modifierFlags: 0
                                      timestamp: 0 windowNumber: [window windowNumber] context: nil
                                    eventNumber: 0 clickCount: 1 pressure: 0];
      NSString *afterClose;
      NSString *expected = [shownTitles componentsJoinedByString: @", "];
      NSString *detail;

      ASSIGN (QuirkProbeOverflowShown, @"");
      [GSCurrentServer () setMouseLocation: [window convertBaseToScreen: point]
                                  onScreen: [[window screen] screenNumber]];
      [self after: 0.3 perform: @selector(inspectOverflowMenu:) mode: NSEventTrackingRunLoopMode];
      [NSApp postEvent: up atStart: NO];
      [menuView mouseDown: down];
      afterClose = QuirkProbeVisibleMenus ();
      detail = [NSString stringWithFormat: @"0.3s after a click on the overflow button: showing \"%@\"; "
        @"after a click elsewhere: \"%@\"", QuirkProbeOverflowShown, afterClose];
      if ([expected length] > 0 && [QuirkProbeOverflowShown isEqualToString: expected] && [afterClose length] == 0)
        {
          [self pass: @"menubar-overflow-click" detail: detail];
        }
      else
        {
          [self fail: @"menubar-overflow-click" detail: detail];
        }
    }

  /* Wide again: the bar as it was, ☰ back at the end. */
  [window setFrame: wideFrame display: YES];
  for (i = 0; i < count; i++)
    {
      if ([[wideRects objectAtIndex: i] isEqualToString: NSStringFromRect ([menuView rectOfItemAtIndex: i])] == NO)
        {
          restored = NO;
        }
    }
  widenDetail = [NSString stringWithFormat: @"widened back to %g: rects %@, ☰ at x %g of %g, overflow button %@",
    NSWidth ([menuView bounds]), restored ? @"as before" : @"changed",
    NSMinX ([menuView rectOfItemAtIndex: 0]), NSWidth ([menuView bounds]),
    NSIsEmptyRect ([menuView gnomeThemeOverflowRect]) ? @"gone" : @"still there"];
  if (restored && NSIsEmptyRect ([menuView gnomeThemeOverflowRect])
    && NSMaxX ([menuView rectOfItemAtIndex: 0]) > NSWidth ([menuView bounds]) - 20)
    {
      [self pass: @"menubar-overflow-widens-back" detail: widenDetail];
    }
  else
    {
      [self fail: @"menubar-overflow-widens-back" detail: widenDetail];
    }

  [window orderOut: nil];
  [mainMenu removeItem: appItem];
  for (i = 0; i < [added count]; i++)
    {
      [mainMenu removeItem: [added objectAtIndex: i]];
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
/* The menus a menu bar click showed, seen from inside its tracking loop. */
static NSString *QuirkProbeMenuBarOpen = nil;
static BOOL QuirkProbeMenuBarItemPicked = NO;
static NSWindow *QuirkProbeMenuBarItemWindow = nil;
static NSValue *QuirkProbeMenuBarItemPoint = nil;

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

/* The titles of the vertical menus showing, as "File: New, Open | ...". */
static NSString *
QuirkProbeVisibleMenus (void)
{
  NSEnumerator *enumerator = [[NSApp windows] objectEnumerator];
  NSMutableArray *menus = [NSMutableArray array];
  NSWindow *window;

  while ((window = [enumerator nextObject]) != nil)
    {
      NSMenuView *menuView = (NSMenuView *)QuirkProbeFindViewOfClass ([window contentView], [NSMenuView class]);

      if ([window isVisible] && menuView != nil && [menuView isHorizontal] == NO)
        {
          [menus addObject: [[menuView menu] title]];
        }
    }
  return [menus componentsJoinedByString: @", "];
}

/* Fires while a menu bar menu is tracking: note what's showing, move the
   pointer off the bar, then click there. */
- (void) inspectMenuBarMenu: (NSTimer *)timer
{
  ASSIGN (QuirkProbeMenuBarOpen, QuirkProbeVisibleMenus ());
  [GSCurrentServer () setMouseLocation: [_controlsWindow convertBaseToScreen: NSMakePoint (850, 20)]
                              onScreen: [[_controlsWindow screen] screenNumber]];
  [self after: 0.2 perform: @selector(clickOffMenuBar:) mode: NSEventTrackingRunLoopMode];
}

- (void) clickOffMenuBar: (NSTimer *)timer
{
  NSPoint point = NSMakePoint (850, 20);
  NSEvent *down = [NSEvent mouseEventWithType: NSLeftMouseDown location: point modifierFlags: 0
                                    timestamp: 0 windowNumber: [_controlsWindow windowNumber] context: nil
                                  eventNumber: 0 clickCount: 1 pressure: 1];
  NSEvent *up = [NSEvent mouseEventWithType: NSLeftMouseUp location: point modifierFlags: 0
                                  timestamp: 0 windowNumber: [_controlsWindow windowNumber] context: nil
                                eventNumber: 0 clickCount: 1 pressure: 0];

  [NSApp postEvent: down atStart: NO];
  [NSApp postEvent: up atStart: NO];
}

/* Fires while a pop-up button's menu is tracking: note whether it's
   showing, then click elsewhere to close it. */
- (void) inspectPopUpMenu: (NSTimer *)timer
{
  NSWindow *menuWindow = [[[_popUpButton menu] menuRepresentation] window];

  ASSIGN (QuirkProbeMenuBarOpen, (menuWindow != nil && [menuWindow isVisible]) ? @"menu" : @"");
  [GSCurrentServer () setMouseLocation: [_controlsWindow convertBaseToScreen: NSMakePoint (850, 20)]
                              onScreen: [[_controlsWindow screen] screenNumber]];
  [self after: 0.2 perform: @selector(clickOffMenuBar:) mode: NSEventTrackingRunLoopMode];
}

/* A click on a pop-up button opens its menu and the menu stays open: its
   menu opens on the press, and the release (here already queued) used to
   end the tracking, picking the current item and closing the menu at once
   (when the release came before the tracking, as while the menu's window
   was first made, the menu stayed open: so only from the second click on).
   A click elsewhere closes it and changes nothing. */
- (void) checkPopUpClick
{
  NSRect frame = [_popUpButton convertRect: [_popUpButton bounds] toView: nil];
  NSPoint point = NSMakePoint (NSMidX (frame), NSMidY (frame));
  NSString *before = [_popUpButton titleOfSelectedItem];
  NSMutableArray *opened = [NSMutableArray array];
  NSWindow *menuWindow;
  NSString *detail;
  int i;

  if ([[NSUserDefaults standardUserDefaults] boolForKey: @"ProbeOwnsDisplay"] == NO)
    {
      [self skip: @"popup-click-stays-open" detail: @"moves the pointer: only on the probe's own Xvfb"];
      return;
    }
  for (i = 0; i < 3; i++)
    {
      NSEvent *down = [NSEvent mouseEventWithType: NSLeftMouseDown location: point modifierFlags: 0
                                        timestamp: 0 windowNumber: [_controlsWindow windowNumber] context: nil
                                      eventNumber: 0 clickCount: 1 pressure: 1];
      NSEvent *up = [NSEvent mouseEventWithType: NSLeftMouseUp location: point modifierFlags: 0
                                      timestamp: 0 windowNumber: [_controlsWindow windowNumber] context: nil
                                    eventNumber: 0 clickCount: 1 pressure: 0];

      ASSIGN (QuirkProbeMenuBarOpen, @"");
      [GSCurrentServer () setMouseLocation: [_controlsWindow convertBaseToScreen: point]
                                  onScreen: [[_controlsWindow screen] screenNumber]];
      [self after: 0.3 perform: @selector(inspectPopUpMenu:) mode: NSEventTrackingRunLoopMode];
      [NSApp postEvent: up atStart: NO];
      [_popUpButton mouseDown: down];
      [opened addObject: [QuirkProbeMenuBarOpen length] > 0 ? @"open" : @"closed"];
    }
  menuWindow = [[[_popUpButton menu] menuRepresentation] window];
  detail = [NSString stringWithFormat: @"0.3s after each of 3 clicks: %@; after a click elsewhere: %@, selection %@ -> %@",
    [opened componentsJoinedByString: @", "],
    [menuWindow isVisible] ? @"showing" : @"closed", before, [_popUpButton titleOfSelectedItem]];
  if ([opened containsObject: @"closed"] == NO && [menuWindow isVisible] == NO
    && [before isEqualToString: [_popUpButton titleOfSelectedItem]])
    {
      [self pass: @"popup-click-stays-open" detail: detail];
    }
  else
    {
      [self fail: @"popup-click-stays-open" detail: detail];
    }
}

/* Clicks a menu bar title, as a click with the pointer on it: the release
   is already queued when the press is handled. */
/* Presses a menu bar title and holds it: no release follows. */
- (void) pressMenuBar: (NSMenuView *)bar item: (NSInteger)index
{
  NSRect title = [bar convertRect: [bar rectOfItemAtIndex: index] toView: nil];
  NSPoint point = NSMakePoint (NSMidX (title), NSMidY (title));
  NSEvent *down = [NSEvent mouseEventWithType: NSLeftMouseDown location: point modifierFlags: 0
                                    timestamp: 0 windowNumber: [_controlsWindow windowNumber] context: nil
                                  eventNumber: 0 clickCount: 1 pressure: 1];

  [GSCurrentServer () setMouseLocation: [_controlsWindow convertBaseToScreen: point]
                              onScreen: [[_controlsWindow screen] screenNumber]];
  [bar mouseDown: down];
}

- (void) clickMenuBar: (NSMenuView *)bar item: (NSInteger)index
{
  NSRect title = [bar convertRect: [bar rectOfItemAtIndex: index] toView: nil];
  NSPoint point = NSMakePoint (NSMidX (title), NSMidY (title));
  NSEvent *down = [NSEvent mouseEventWithType: NSLeftMouseDown location: point modifierFlags: 0
                                    timestamp: 0 windowNumber: [_controlsWindow windowNumber] context: nil
                                  eventNumber: 0 clickCount: 1 pressure: 1];
  NSEvent *up = [NSEvent mouseEventWithType: NSLeftMouseUp location: point modifierFlags: 0
                                  timestamp: 0 windowNumber: [_controlsWindow windowNumber] context: nil
                                eventNumber: 0 clickCount: 1 pressure: 0];

  [GSCurrentServer () setMouseLocation: [_controlsWindow convertBaseToScreen: point]
                              onScreen: [[_controlsWindow screen] screenNumber]];
  [NSApp postEvent: up atStart: NO];
  [bar mouseDown: down];
}

/* A click on a menu bar title opens its menu and the menu stays open
   (libs-gui 0.32 closed it on the release: upstream item 8,
   plugins-themes-Adwaita#5); a click elsewhere or Escape closes it. Moves
   the pointer, so only on the probe's own display. */
- (void) checkMenuBarClick
{
  NSMenuView *bar = nil;
  NSEnumerator *enumerator;
  NSView *view;
  NSInteger index;
  NSString *detail;
  NSString *afterClose;

  if (NSInterfaceStyleForKey (@"NSMenuInterfaceStyle", nil) != NSWindows95InterfaceStyle
    || [[[NSUserDefaults standardUserDefaults] stringForKey: @"GnomeThemeMenuStyle"] isEqualToString: @"primary"])
    {
      [self skip: @"menubar-click-opens" detail: @"needs the menu bar (NSWindows95InterfaceStyle, not primary)"];
      return;
    }
  if ([[NSUserDefaults standardUserDefaults] boolForKey: @"ProbeOwnsDisplay"] == NO)
    {
      [self skip: @"menubar-click-opens" detail: @"moves the pointer: only on the probe's own Xvfb"];
      return;
    }
  enumerator = [[[[_controlsWindow contentView] superview] subviews] objectEnumerator];
  while ((view = [enumerator nextObject]) != nil && bar == nil)
    {
      NSMenuView *found = (NSMenuView *)QuirkProbeFindViewOfClass (view, [NSMenuView class]);

      if (found != nil && [found isHorizontal])
        {
          bar = found;
        }
    }
  index = [[NSApp mainMenu] indexOfItemWithTitle: @"File"];
  if (bar == nil || index < 0)
    {
      [self fail: @"menubar-click-opens" detail: @"no menu bar with a File menu"];
      return;
    }

  ASSIGN (QuirkProbeMenuBarOpen, @"");
  [self after: 0.3 perform: @selector(inspectMenuBarMenu:) mode: NSEventTrackingRunLoopMode];
  [self clickMenuBar: bar item: index];
  afterClose = QuirkProbeVisibleMenus ();
  detail = [NSString stringWithFormat: @"0.3s after a click on File: showing \"%@\"; after a click elsewhere: \"%@\"",
    QuirkProbeMenuBarOpen, afterClose];
  if ([QuirkProbeMenuBarOpen isEqualToString: @"File"] && [afterClose length] == 0)
    {
      [self pass: @"menubar-click-opens" detail: detail];
    }
  else
    {
      [self fail: @"menubar-click-opens" detail: detail];
    }

  /* A press alone opens it, as GTK's menu bar does (the theme used to
     hold the press until its release); a click elsewhere closes it. */
  ASSIGN (QuirkProbeMenuBarOpen, @"");
  [self after: 0.3 perform: @selector(inspectMenuBarMenu:) mode: NSEventTrackingRunLoopMode];
  [self pressMenuBar: bar item: index];
  afterClose = QuirkProbeVisibleMenus ();
  detail = [NSString stringWithFormat: @"0.3s into a press on File: showing \"%@\"; after a click elsewhere: \"%@\"",
    QuirkProbeMenuBarOpen, afterClose];
  if ([QuirkProbeMenuBarOpen isEqualToString: @"File"] && [afterClose length] == 0)
    {
      [self pass: @"menubar-press-opens" detail: detail];
    }
  else
    {
      [self fail: @"menubar-press-opens" detail: detail];
    }

  /* The same for the application menu, drawn as ☰ at the bar's end. */
  {
    NSString *name = [[NSProcessInfo processInfo] processName];
    NSMenu *appMenu = AUTORELEASE ([[NSMenu alloc] initWithTitle: name]);
    NSMenuItem *appItem = AUTORELEASE ([[NSMenuItem alloc] initWithTitle: name action: NULL keyEquivalent: @""]);

    [appMenu addItemWithTitle: @"Info" action: NULL keyEquivalent: @""];
    [appItem setSubmenu: appMenu];
    [[NSApp mainMenu] insertItem: appItem atIndex: 0];
    [bar sizeToFit];
    ASSIGN (QuirkProbeMenuBarOpen, @"");
    [self after: 0.3 perform: @selector(inspectMenuBarMenu:) mode: NSEventTrackingRunLoopMode];
    [self clickMenuBar: bar item: 0];
    afterClose = QuirkProbeVisibleMenus ();
    detail = [NSString stringWithFormat: @"0.3s after a click on ☰ at x %g: showing \"%@\"; after a click elsewhere: \"%@\"",
      NSMinX ([bar rectOfItemAtIndex: 0]), QuirkProbeMenuBarOpen, afterClose];
    [[NSApp mainMenu] removeItem: appItem];
    [bar sizeToFit];
    if ([QuirkProbeMenuBarOpen isEqualToString: name] && [afterClose length] == 0)
      {
        [self pass: @"menubar-click-opens-app-menu" detail: detail];
      }
    else
      {
        [self fail: @"menubar-click-opens-app-menu" detail: detail];
      }
  }

  /* Escape closes it. */
  {
    NSTimer *fallback = [NSTimer timerWithTimeInterval: 1.5 target: self selector: @selector(closeMenuAfterEscape:)
                                              userInfo: nil repeats: NO];

    QuirkProbeEscapeNeededClick = NO;
    [[NSRunLoop currentRunLoop] addTimer: fallback forMode: NSEventTrackingRunLoopMode];
    ASSIGN (QuirkProbeMenuBarOpen, @"");
    [self after: 0.3 perform: @selector(pressEscapeOnMenuBar:) mode: NSEventTrackingRunLoopMode];
    [self clickMenuBar: bar item: index];
    [fallback invalidate];
    afterClose = QuirkProbeVisibleMenus ();
    detail = [NSString stringWithFormat: @"showing \"%@\" before Escape; after it: %@, showing \"%@\"",
      QuirkProbeMenuBarOpen,
      QuirkProbeEscapeNeededClick ? @"still tracking (closed by a click)" : @"tracking ended", afterClose];
    if ([QuirkProbeMenuBarOpen isEqualToString: @"File"] && QuirkProbeEscapeNeededClick == NO
      && [afterClose length] == 0)
      {
        [self pass: @"menubar-click-escape" detail: detail];
      }
    else
      {
        [self fail: @"menubar-click-escape" detail: detail];
      }
  }

  /* A click on an item of the open menu runs it. Escape's spare release
     (for libs-gui master) is still queued: dispatch it, as the main loop
     would. */
  {
    NSEvent *pending;

    while ((pending = [NSApp nextEventMatchingMask: NSAnyEventMask untilDate: [NSDate distantPast]
                                            inMode: NSDefaultRunLoopMode dequeue: YES]) != nil)
      {
        [NSApp sendEvent: pending];
      }
  }
  {
    NSMenu *fileMenu = [[[NSApp mainMenu] itemAtIndex: index] submenu];
    NSMenuItem *probeItem = [fileMenu addItemWithTitle: @"Probe Item"
                                                action: @selector(menuBarItemPicked:)
                                         keyEquivalent: @""];

    [probeItem setTarget: self];
    QuirkProbeMenuBarItemPicked = NO;
    [self after: 0.3 perform: @selector(clickProbeItem:) mode: NSEventTrackingRunLoopMode];
    [self clickMenuBar: bar item: index];
    afterClose = QuirkProbeVisibleMenus ();
    [fileMenu removeItem: probeItem];
    detail = [NSString stringWithFormat: @"a click on File, then on its item: %@; showing \"%@\" after",
      QuirkProbeMenuBarItemPicked ? @"the item ran" : @"the item didn't run", afterClose];
    if (QuirkProbeMenuBarItemPicked && [afterClose length] == 0)
      {
        [self pass: @"menubar-click-picks" detail: detail];
      }
    else
      {
        [self fail: @"menubar-click-picks" detail: detail];
      }
  }
  [GSCurrentServer () setMouseLocation: NSMakePoint (0, 0) onScreen: [[_controlsWindow screen] screenNumber]];
}

- (void) pressEscapeOnMenuBar: (NSTimer *)timer
{
  ASSIGN (QuirkProbeMenuBarOpen, QuirkProbeVisibleMenus ());
  [self pressEscape: timer];
}

- (void) menuBarItemPicked: (id)sender
{
  QuirkProbeMenuBarItemPicked = YES;
}

/* Fires while File is open from a click: point at its probe item, then
   click it. */
- (void) clickProbeItem: (NSTimer *)timer
{
  NSEnumerator *enumerator = [[NSApp windows] objectEnumerator];
  NSWindow *window;

  while ((window = [enumerator nextObject]) != nil)
    {
      NSMenuView *menuView = (NSMenuView *)QuirkProbeFindViewOfClass ([window contentView], [NSMenuView class]);
      NSInteger item = [[menuView menu] indexOfItemWithTitle: @"Probe Item"];

      if ([window isVisible] && menuView != nil && [menuView isHorizontal] == NO && item >= 0)
        {
          NSRect rect = [menuView convertRect: [menuView rectOfItemAtIndex: item] toView: nil];
          NSPoint point = NSMakePoint (NSMidX (rect), NSMidY (rect));

          [GSCurrentServer () setMouseLocation: [window convertBaseToScreen: point]
                                      onScreen: [[window screen] screenNumber]];
          ASSIGN (QuirkProbeMenuBarItemWindow, window);
          ASSIGN (QuirkProbeMenuBarItemPoint, [NSValue valueWithPoint: point]);
          [self after: 0.2 perform: @selector(clickPointedItem:) mode: NSEventTrackingRunLoopMode];
          return;
        }
    }
  /* Not open: end the tracking. */
  [self clickOffMenuBar: timer];
}

- (void) clickPointedItem: (NSTimer *)timer
{
  NSPoint point = [QuirkProbeMenuBarItemPoint pointValue];
  NSInteger number = [QuirkProbeMenuBarItemWindow windowNumber];

  [NSApp postEvent: [NSEvent mouseEventWithType: NSLeftMouseDown location: point modifierFlags: 0
                                      timestamp: 0 windowNumber: number context: nil
                                    eventNumber: 0 clickCount: 1 pressure: 1]
           atStart: NO];
  [NSApp postEvent: [NSEvent mouseEventWithType: NSLeftMouseUp location: point modifierFlags: 0
                                      timestamp: 0 windowNumber: number context: nil
                                    eventNumber: 0 clickCount: 1 pressure: 0]
           atStart: NO];
  DESTROY (QuirkProbeMenuBarItemWindow);
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

/* A red square, named `name`. */
static NSImage *
QuirkProbeRedImage(NSString *name)
{
  NSImage *image = AUTORELEASE ([[NSImage alloc] initWithSize: NSMakeSize (16, 16)]);

  [image lockFocus];
  [[NSColor colorWithCalibratedRed: 1.0 green: 0.0 blue: 0.0 alpha: 1.0] set];
  NSRectFill (NSMakeRect (0, 0, 16, 16));
  [image unlockFocus];
  [image setName: name];
  return image;
}

/* The colour at a button's centre, where its image is. */
static NSColor *
QuirkProbeButtonImageColor(NSButton *button)
{
  NSBitmapImageRep *rep = QuirkProbeRender (button);
  NSInteger bits = [rep bitsPerSample];
  CGFloat maxValue = (bits >= 16) ? 65535.0 : (CGFloat)((1u << bits) - 1);
  BOOL alphaFirst = [rep hasAlpha] && ([rep bitmapFormat] & NSAlphaFirstBitmapFormat) != 0;
  NSInteger start = alphaFirst ? 1 : 0;
  NSUInteger pixel[5];

  if ([rep samplesPerPixel] < 3 || [rep samplesPerPixel] > 5)
    {
      return [NSColor clearColor];
    }
  [rep getPixel: pixel atX: [rep pixelsWide] / 2 y: [rep pixelsHigh] / 2];
  return [NSColor colorWithCalibratedRed: pixel[start] / maxValue green: pixel[start + 1] / maxValue
                                    blue: pixel[start + 2] / maxValue alpha: 1.0];
}

/* Template (symbolic) images are tinted with the text colour: red ones
   named "...Template" or "...-symbolic" come out neutral (dark in the
   light palette, light in the dark one), and in the title colour on a
   suggested button; an image that isn't a template keeps its colours
   (plugins-themes-Adwaita#32). */
- (void) checkTemplateImages
{
  NSWindow *window = [self windowWithFrame: NSMakeRect (60, 60, 300, 80) title: @"Probe Templates"];
  /* Image names are unique: -setName: refuses one already in use. */
  NSString *names[4] = { @"QuirkProbeIconTemplate", @"quirk-probe-icon-symbolic", @"QuirkProbeIcon",
                         @"QuirkProbeDefaultIconTemplate" };
  NSColor *colors[4];
  NSColor *text = [[NSColor controlTextColor] colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
  NSColor *suggested = [[NSColor selectedControlTextColor] colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
  BOOL darkText = text == nil || [text brightnessComponent] < 0.5;
  BOOL darkSuggested = suggested != nil && [suggested brightnessComponent] < 0.5;
  BOOL ok = YES;
  NSMutableArray *parts = [NSMutableArray array];
  int i;

  for (i = 0; i < 4; i++)
    {
      NSButton *button = AUTORELEASE ([[NSButton alloc] initWithFrame: NSMakeRect (10 + 70 * i, 20, 60, 34)]);

      [button setImage: QuirkProbeRedImage (names[i])];
      [button setImagePosition: NSImageOnly];
      [button setBezelStyle: NSRoundedBezelStyle];
      if (i == 3)
        {
          [button setKeyEquivalent: @"\r"];
        }
      [[window contentView] addSubview: button];
    }
  [window orderFront: nil];
  [window display];
  for (i = 0; i < 4; i++)
    {
      colors[i] = QuirkProbeButtonImageColor ([[[window contentView] subviews] objectAtIndex: i]);
    }
  /* A segmented control's segments, one selected (plugins-themes-Adwaita#37). */
  {
    NSSegmentedControl *segments = AUTORELEASE ([[NSSegmentedControl alloc] initWithFrame: NSMakeRect (10, 0, 120, 30)]);
    NSBitmapImageRep *rep;
    NSInteger bits;
    CGFloat maxValue;
    NSInteger start;
    NSUInteger pixel[5];
    int k;

    [segments setSegmentCount: 2];
    [segments setImage: QuirkProbeRedImage (@"QuirkProbeSegmentTemplate") forSegment: 0];
    [segments setImage: QuirkProbeRedImage (@"quirk-probe-segment-symbolic") forSegment: 1];
    [segments setWidth: 60 forSegment: 0];
    [segments setWidth: 60 forSegment: 1];
    [segments setSelectedSegment: 1];
    [[window contentView] addSubview: segments];
    [window display];
    rep = QuirkProbeRender (segments);
    bits = [rep bitsPerSample];
    maxValue = (bits >= 16) ? 65535.0 : (CGFloat)((1u << bits) - 1);
    start = ([rep hasAlpha] && ([rep bitmapFormat] & NSAlphaFirstBitmapFormat)) ? 1 : 0;
    for (k = 0; k < 2; k++)
      {
        CGFloat r, g, b;

        [rep getPixel: pixel atX: (NSInteger)(([rep pixelsWide] / 4.0) * (1 + 2 * k)) y: [rep pixelsHigh] / 2];
        r = pixel[start] / maxValue; g = pixel[start + 1] / maxValue; b = pixel[start + 2] / maxValue;
        ok = ok && fabs (r - g) < 0.08 && fabs (g - b) < 0.08 && (darkText ? r < 0.5 : r > 0.5);
        [parts addObject: [NSString stringWithFormat: @"segment %d%@ %.2f/%.2f/%.2f", k,
                                   k == 1 ? @" (selected)" : @"", r, g, b]];
      }
  }
  [window orderOut: nil];

  for (i = 0; i < 4; i++)
    {
      NSColor *c = colors[i];
      CGFloat r = [c redComponent], g = [c greenComponent], b = [c blueComponent];
      BOOL neutral = fabs (r - g) < 0.08 && fabs (g - b) < 0.08;
      BOOL want;

      switch (i)
        {
          case 0: case 1: want = neutral && (darkText ? r < 0.5 : r > 0.5); break;
          case 2: want = r > 0.8 && g < 0.2 && b < 0.2; break;
          /* The default button's title colour, whatever the palette
             makes it. */
          default: want = darkSuggested ? (r < 0.3 && g < 0.3 && b < 0.3) : (neutral && r > 0.85); break;
        }
      ok = ok && want;
      [parts addObject: [NSString stringWithFormat: @"%@ %.2f/%.2f/%.2f",
                                 (i == 0 ? @"...Template" : i == 1 ? @"...-symbolic" : i == 2 ? @"not a template"
                                  : @"...Template on the default button"), r, g, b]];
    }
  if (ok)
    {
      [self pass: @"template-images" detail: [parts componentsJoinedByString: @"; "]];
    }
  else
    {
      [self fail: @"template-images" detail: [parts componentsJoinedByString: @"; "]];
    }
}

/* r, g, b (0-255) at a view's pixel, from the top left. */
static void
QuirkProbePixelAt(NSBitmapImageRep *rep, NSInteger x, NSInteger y, NSUInteger rgb[3])
{
  NSInteger bits = [rep bitsPerSample];
  NSUInteger maxValue = (bits >= 16) ? 65535 : ((1u << bits) - 1);
  NSInteger start = ([rep hasAlpha] && ([rep bitmapFormat] & NSAlphaFirstBitmapFormat)) ? 1 : 0;
  NSUInteger pixel[5];
  int i;

  [rep getPixel: pixel atX: x y: y];
  for (i = 0; i < 3; i++)
    {
      rgb[i] = pixel[start + i] * 255 / maxValue;
    }
}

/* Whether a pixel is within `tolerance` of an expected colour (0xRRGGBB),
   in every channel. */
static BOOL
QuirkProbeNear(const NSUInteger rgb[3], unsigned int expected, NSUInteger tolerance)
{
  long want[3] = { (expected >> 16) & 0xff, (expected >> 8) & 0xff, expected & 0xff };
  int i;

  for (i = 0; i < 3; i++)
    {
      if (labs ((long)rgb[i] - want[i]) > (long)tolerance)
        {
          return NO;
        }
    }
  return YES;
}

static NSString *
QuirkProbeHex(const NSUInteger rgb[3])
{
  return [NSString stringWithFormat: @"#%02lx%02lx%02lx",
    (unsigned long)rgb[0], (unsigned long)rgb[1], (unsigned long)rgb[2]];
}

/* libadwaita 1.7's control colours, measured from its reference app on the
   same display (Reference/AdwaitaDemo), in the palette the run uses (light
   or dark by the window colour, high contrast from -ProbeHighContrast):
   the window and a button (the foreground at 10% over it, #60), the
   default button's accent (#55), an unchecked radio's and check box's
   ring (#57) and a button's outline (#61). */
- (void) checkControlColors
{
  BOOL highContrast = [[NSUserDefaults standardUserDefaults] boolForKey: @"ProbeHighContrast"];
  NSColor *windowColor = [[NSColor windowBackgroundColor] colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
  BOOL dark = [windowColor redComponent] < 0.5;
  NSString *style = dark ? (highContrast ? @"high contrast dark" : @"dark")
                         : (highContrast ? @"high contrast" : @"light");
  NSWindow *window = [self windowWithFrame: NSMakeRect (60, 60, 320, 120) title: @"Probe Control Colours"];
  NSButton *secondary = AUTORELEASE ([[NSButton alloc] initWithFrame: NSMakeRect (20, 70, 120, 34)]);
  NSButton *defaultButton = AUTORELEASE ([[NSButton alloc] initWithFrame: NSMakeRect (170, 70, 120, 34)]);
  NSButton *radio = AUTORELEASE ([[NSButton alloc] initWithFrame: NSMakeRect (20, 20, 120, 24)]);
  NSButton *checkBox = AUTORELEASE ([[NSButton alloc] initWithFrame: NSMakeRect (170, 20, 120, 24)]);
  NSView *frameView;
  NSBitmapImageRep *rep;
  NSUInteger windowRGB[3], buttonRGB[3], defaultRGB[3], titleRGB[3] = { 0, 0, 0 };
  NSUInteger radioRGB[3] = { 0, 0, 0 }, checkRGB[3] = { 0, 0, 0 }, edgeRGB[3];
  long radioStep = -1, checkStep = -1;
  unsigned int ring;
  NSRect inWindow;
  NSString *detail;
  NSInteger x;

  [secondary setTitle: @""];
  [defaultButton setTitle: @"Default"];
  [defaultButton setKeyEquivalent: @"\r"];
  [radio setButtonType: NSRadioButton];
  [radio setTitle: @""];
  [checkBox setButtonType: NSSwitchButton];
  [checkBox setTitle: @""];
  [[window contentView] addSubview: secondary];
  [[window contentView] addSubview: defaultButton];
  [[window contentView] addSubview: radio];
  [[window contentView] addSubview: checkBox];
  [window orderFront: nil];
  [window display];
  frameView = [[window contentView] superview];
  rep = QuirkProbeRender (frameView);
#define QUIRK_PROBE_SAMPLE(view, dx, dy, rgb) \
  inWindow = [view convertRect: [view bounds] toView: nil]; \
  QuirkProbePixelAt (rep, (NSInteger)(NSMinX (inWindow) + (dx)), \
                     (NSInteger)(NSHeight ([frameView bounds]) - NSMaxY (inWindow) + (dy)), rgb)
  QUIRK_PROBE_SAMPLE (secondary, -10, 17, windowRGB);
  QUIRK_PROBE_SAMPLE (secondary, 60, 17, buttonRGB);
  QUIRK_PROBE_SAMPLE (secondary, 60, 0, edgeRGB);
  QUIRK_PROBE_SAMPLE (defaultButton, 8, 17, defaultRGB);
  /* The title's brightest pixel along the button's middle. */
  for (x = 20; x < 100; x++)
    {
      NSUInteger rgb[3];

      QUIRK_PROBE_SAMPLE (defaultButton, x, 17, rgb);
      if (rgb[0] + rgb[1] + rgb[2] > titleRGB[0] + titleRGB[1] + titleRGB[2])
        {
          titleRGB[0] = rgb[0]; titleRGB[1] = rgb[1]; titleRGB[2] = rgb[2];
        }
    }
  /* An unchecked indicator's ring: the pixel along its middle row that is
     furthest from the window. */
  for (x = 0; x < 30; x++)
    {
      NSUInteger rgb[3];
      long step;

      QUIRK_PROBE_SAMPLE (radio, x, 12, rgb);
      step = labs ((long)rgb[0] - (long)windowRGB[0]) + labs ((long)rgb[1] - (long)windowRGB[1])
        + labs ((long)rgb[2] - (long)windowRGB[2]);
      if (step > radioStep)
        {
          radioStep = step; radioRGB[0] = rgb[0]; radioRGB[1] = rgb[1]; radioRGB[2] = rgb[2];
        }
      QUIRK_PROBE_SAMPLE (checkBox, x, 12, rgb);
      step = labs ((long)rgb[0] - (long)windowRGB[0]) + labs ((long)rgb[1] - (long)windowRGB[1])
        + labs ((long)rgb[2] - (long)windowRGB[2]);
      if (step > checkStep)
        {
          checkStep = step; checkRGB[0] = rgb[0]; checkRGB[1] = rgb[1]; checkRGB[2] = rgb[2];
        }
    }
#undef QUIRK_PROBE_SAMPLE
  [window orderOut: nil];

  detail = [NSString stringWithFormat: @"%@: window %@ (want %s), button %@ (want %s)", style,
    QuirkProbeHex (windowRGB), dark ? "#222226" : "#fafafb",
    QuirkProbeHex (buttonRGB), dark ? "#38383b" : "#e6e6e7"];
  if (QuirkProbeNear (windowRGB, dark ? 0x222226 : 0xfafafb, 1)
    && QuirkProbeNear (buttonRGB, dark ? 0x38383b : 0xe6e6e7, 1))
    {
      [self pass: @"control-colors-window-button" detail: detail];
    }
  else
    {
      [self fail: @"control-colors-window-button" detail: detail];
    }

  /* The default button is libadwaita's suggested action in every palette:
     accent_bg_color #3584e4 with a white title (plugins-themes-Adwaita#55). */
  detail = [NSString stringWithFormat: @"%@: fill %@ (want #3584e4), title's brightest pixel %@ (want white)",
    style, QuirkProbeHex (defaultRGB), QuirkProbeHex (titleRGB)];
  if (QuirkProbeNear (defaultRGB, 0x3584e4, 1)
    && titleRGB[0] >= 240 && titleRGB[1] >= 240 && titleRGB[2] >= 240)
    {
      [self pass: @"control-colors-default-button" detail: detail];
    }
  else
    {
      [self fail: @"control-colors-default-button" detail: detail];
    }

  /* An unchecked radio and check box show libadwaita's ring: the
     foreground at 15% over the window, 50% in high contrast. In the dark
     palette they used to be the window's own colour (#57). */
  ring = dark ? (highContrast ? 0x919193 : 0x434346) : (highContrast ? 0x969699 : 0xdddddd);
  detail = [NSString stringWithFormat: @"%@: radio ring %@, check box ring %@ (want #%06x)",
    style, QuirkProbeHex (radioRGB), QuirkProbeHex (checkRGB), ring];
  if (QuirkProbeNear (radioRGB, ring, 6) && QuirkProbeNear (checkRGB, ring, 6))
    {
      [self pass: @"control-colors-unchecked-indicators" detail: detail];
    }
  else
    {
      [self fail: @"control-colors-unchecked-indicators" detail: detail];
    }

  /* A button's top edge: no outline in libadwaita's normal styles (the edge
     pixel is between the window and the fill; the light palette's used to
     be a #dfdfdf line), and in high contrast its 1px outline, the
     foreground at 50% (#61). */
  {
    unsigned int outline = dark ? 0x919193 : 0x969699;
    BOOL between = YES;
    int i;

    for (i = 0; i < 3; i++)
      {
        NSUInteger low = MIN (windowRGB[i], buttonRGB[i]);
        NSUInteger high = MAX (windowRGB[i], buttonRGB[i]);

        if (edgeRGB[i] + 1 < low || edgeRGB[i] > high + 1)
          {
            between = NO;
          }
      }
    detail = [NSString stringWithFormat: @"%@: button edge %@ (want %@)", style, QuirkProbeHex (edgeRGB),
      highContrast ? [NSString stringWithFormat: @"#%06x, the outline", outline]
                   : @"between the window and the fill"];
    if (highContrast ? QuirkProbeNear (edgeRGB, outline, 8) : between)
      {
        [self pass: @"control-colors-outline" detail: detail];
      }
    else
      {
        [self fail: @"control-colors-outline" detail: detail];
      }
  }
}

/* NSSwitch as libadwaita's switch: a 46x26 pill, the accent when on with
   the knob at the end, a neutral track when off with the knob at the start
   (plugins-themes-Adwaita#35). */
/* The slider's knob as libadwaita's: 20px with its outline and shadow,
   and lighter than the trough in any palette (the dark palette's knob
   was the window's colour and vanished; plugins-themes-Adwaita#56). */
- (void) checkSliderKnob
{
  NSWindow *window = [self windowWithFrame: NSMakeRect (60, 60, 260, 80) title: @"Probe Slider"];
  NSSlider *slider = AUTORELEASE ([[NSSlider alloc] initWithFrame: NSMakeRect (20, 20, 200, 30)]);
  NSView *frameView;
  NSBitmapImageRep *rep;
  NSRect knob;
  NSUInteger centre[3], trough[3], background[3], pixel[3];
  NSInteger x, y, top = -1, bottom = -1, backgroundSum, frameHeight;
  NSString *detail;

  [slider setMinValue: 0.0];
  [slider setMaxValue: 100.0];
  [slider setDoubleValue: 30.0];
  [[window contentView] addSubview: slider];
  [window orderFront: nil];
  [window display];
  frameView = [[window contentView] superview];
  rep = QuirkProbeRender (frameView);
  frameHeight = (NSInteger)NSHeight ([frameView bounds]);
  knob = [slider convertRect: [[slider cell] knobRectFlipped: [slider isFlipped]] toView: nil];
  x = (NSInteger)floor (NSMidX (knob));
  y = frameHeight - (NSInteger)floor (NSMidY (knob)) - 1;
  QuirkProbePixelAt (rep, x, y, centre);
  /* The trough to the right of the knob: the slider is at 30%. */
  QuirkProbePixelAt (rep, x + 60, y, trough);
  QuirkProbePixelAt (rep, x, y - 20, background);
  backgroundSum = (NSInteger)(background[0] + background[1] + background[2]);
  for (y = frameHeight - (NSInteger)floor (NSMidY (knob)) - 16; y <= frameHeight - (NSInteger)floor (NSMidY (knob)) + 16; y++)
    {
      QuirkProbePixelAt (rep, x, y, pixel);
      if (labs ((NSInteger)(pixel[0] + pixel[1] + pixel[2]) - backgroundSum) > 12)
        {
          if (top < 0)
            {
              top = y;
            }
          bottom = y;
        }
    }
  [window orderOut: nil];

  detail = [NSString stringWithFormat: @"knob %ldpx high with its outline and shadow, centre %lu/%lu/%lu, trough %lu/%lu/%lu, window %lu/%lu/%lu",
    (long)(top >= 0 ? bottom - top + 1 : 0),
    (unsigned long)centre[0], (unsigned long)centre[1], (unsigned long)centre[2],
    (unsigned long)trough[0], (unsigned long)trough[1], (unsigned long)trough[2],
    (unsigned long)background[0], (unsigned long)background[1], (unsigned long)background[2]];
  if (top >= 0 && bottom - top + 1 >= 20 && bottom - top + 1 <= 24
      && centre[0] + centre[1] + centre[2] >= trough[0] + trough[1] + trough[2] + 60)
    {
      [self pass: @"slider-knob" detail: detail];
    }
  else
    {
      [self fail: @"slider-knob" detail: detail];
    }
}

/* A text view's scroll view draws libadwaita's frame: one 1px line at its
   edge and rounded corners, where GNUstep's bezel drew two dark lines and
   square corners (plugins-themes-Adwaita#58). */
- (void) checkScrollViewFrame
{
  NSWindow *window = [self windowWithFrame: NSMakeRect (60, 60, 260, 160) title: @"Probe Frame"];
  NSScrollView *scrollView = AUTORELEASE ([[NSScrollView alloc] initWithFrame: NSMakeRect (20, 20, 220, 120)]);
  NSTextView *textView = AUTORELEASE ([[NSTextView alloc] initWithFrame: NSMakeRect (0, 0, 200, 300)]);
  NSView *frameView;
  NSBitmapImageRep *rep;
  NSRect inWindow;
  NSUInteger corner[3], outside[3], inside[3], pixel[3];
  NSInteger left, top, x, y, lines = 0, insideSum;
  NSString *detail;

  [scrollView setBorderType: NSBezelBorder];
  [scrollView setHasVerticalScroller: YES];
  [scrollView setDocumentView: textView];
  [[window contentView] addSubview: scrollView];
  [window orderFront: nil];
  [window display];
  frameView = [[window contentView] superview];
  rep = QuirkProbeRender (frameView);
  inWindow = [scrollView convertRect: [scrollView bounds] toView: nil];
  left = (NSInteger)NSMinX (inWindow);
  top = (NSInteger)(NSHeight ([frameView bounds]) - NSMaxY (inWindow));
  QuirkProbePixelAt (rep, left, top, corner);
  QuirkProbePixelAt (rep, left - 3, top - 3, outside);
  x = left + (NSInteger)NSWidth (inWindow) / 3;
  QuirkProbePixelAt (rep, x, top + 8, inside);
  insideSum = (NSInteger)(inside[0] + inside[1] + inside[2]);
  /* The rows at the top edge that aren't the content's colour. */
  for (y = top; y < top + 5; y++)
    {
      QuirkProbePixelAt (rep, x, y, pixel);
      if (labs ((NSInteger)(pixel[0] + pixel[1] + pixel[2]) - insideSum) > 15)
        {
          lines++;
        }
    }
  [window orderOut: nil];

  detail = [NSString stringWithFormat: @"%ld line(s) at the top edge; corner %lu/%lu/%lu, window %lu/%lu/%lu, content %lu/%lu/%lu",
    (long)lines, (unsigned long)corner[0], (unsigned long)corner[1], (unsigned long)corner[2],
    (unsigned long)outside[0], (unsigned long)outside[1], (unsigned long)outside[2],
    (unsigned long)inside[0], (unsigned long)inside[1], (unsigned long)inside[2]];
  if (lines == 1
      && labs ((NSInteger)(corner[0] + corner[1] + corner[2]) - (NSInteger)(outside[0] + outside[1] + outside[2])) <= 12)
    {
      [self pass: @"scroll-view-frame" detail: detail];
    }
  else
    {
      [self fail: @"scroll-view-frame" detail: detail];
    }
}

- (void) checkSwitch
{
  Class switchClass = NSClassFromString (@"NSSwitch");
  NSWindow *window;
  NSControl *offSwitch, *onSwitch, *disabledSwitch;
  NSBitmapImageRep *offRep, *onRep, *disabledRep;
  NSUInteger onTrack[3], onKnob[3], offTrack[3], offKnob[3], disabledTrack[3];
  NSString *detail;
  BOOL ok;

  if (switchClass == Nil)
    {
      [self skip: @"switch-adwaita" detail: @"no NSSwitch in this libs-gui"];
      return;
    }
  window = [self windowWithFrame: NSMakeRect (60, 60, 200, 80) title: @"Probe Switch"];
  offSwitch = AUTORELEASE ([[switchClass alloc] initWithFrame: NSMakeRect (10, 20, 46, 26)]);
  onSwitch = AUTORELEASE ([[switchClass alloc] initWithFrame: NSMakeRect (80, 20, 46, 26)]);
  [(id)onSwitch setState: NSOnState];
  /* libs-gui 0.32's NSSwitch starts disabled (its _enabled isn't set). */
  [offSwitch setEnabled: YES];
  [onSwitch setEnabled: YES];
  disabledSwitch = AUTORELEASE ([[switchClass alloc] initWithFrame: NSMakeRect (140, 20, 46, 26)]);
  [(id)disabledSwitch setState: NSOnState];
  [disabledSwitch setEnabled: NO];
  [[window contentView] addSubview: offSwitch];
  [[window contentView] addSubview: onSwitch];
  [[window contentView] addSubview: disabledSwitch];
  [window orderFront: nil];
  [window display];
  offRep = QuirkProbeRender (offSwitch);
  onRep = QuirkProbeRender (onSwitch);
  /* The track's free end (6px in from it), and the knob's centre. */
  QuirkProbePixelAt (onRep, 6, [onRep pixelsHigh] / 2, onTrack);
  QuirkProbePixelAt (onRep, [onRep pixelsWide] - 13, [onRep pixelsHigh] / 2, onKnob);
  QuirkProbePixelAt (offRep, [offRep pixelsWide] - 6, [offRep pixelsHigh] / 2, offTrack);
  QuirkProbePixelAt (offRep, 13, [offRep pixelsHigh] / 2, offKnob);
  /* Rendered with the window under it: it's translucent. */
  {
    NSView *frameView = [[window contentView] superview];
    NSRect inWindow = [disabledSwitch convertRect: [disabledSwitch bounds] toView: nil];

    disabledRep = QuirkProbeRender (frameView);
    QuirkProbePixelAt (disabledRep, (NSInteger)NSMinX (inWindow) + 6,
                       (NSInteger)(NSHeight ([frameView bounds]) - NSMidY (inWindow)), disabledTrack);
  }
  [window orderOut: nil];

  detail = [NSString stringWithFormat: @"on: track %lu/%lu/%lu, knob %lu/%lu/%lu; off: track %lu/%lu/%lu, knob %lu/%lu/%lu; "
    @"disabled on: track %lu/%lu/%lu",
    (unsigned long)onTrack[0], (unsigned long)onTrack[1], (unsigned long)onTrack[2],
    (unsigned long)onKnob[0], (unsigned long)onKnob[1], (unsigned long)onKnob[2],
    (unsigned long)offTrack[0], (unsigned long)offTrack[1], (unsigned long)offTrack[2],
    (unsigned long)offKnob[0], (unsigned long)offKnob[1], (unsigned long)offKnob[2],
    (unsigned long)disabledTrack[0], (unsigned long)disabledTrack[1], (unsigned long)disabledTrack[2]];
  /* On: blue track, a light knob. Off: a grey track 15-30% of the way
     from the window to the text (darker in the light palette, lighter in
     the dark), the knob lighter than the track. Disabled: closer to the
     window than the enabled one, still blue. */
  {
    NSColor *windowColor = [[NSColor windowBackgroundColor] colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
    long window = (long)([windowColor redComponent] * 255.0);
    long offStep = labs ((long)offTrack[0] - window);

    ok = onTrack[2] > onTrack[0] + 60 && onKnob[0] > 200 && onKnob[1] > 200 && onKnob[2] > 200
      && labs ((long)offTrack[0] - (long)offTrack[2]) < 12 && offStep >= 20 && offStep <= 80
      && offKnob[0] > offTrack[0] + 15
      && disabledTrack[2] > disabledTrack[0]
      && labs ((long)disabledTrack[0] - window) < labs ((long)onTrack[0] - window);
  }
  if (ok)
    {
      [self pass: @"switch-adwaita" detail: detail];
    }
  else
    {
      [self fail: @"switch-adwaita" detail: detail];
    }
}

/* Overlay scrollbars (GNOME's overlay-scrolling): the content runs under
   the scroller, which isn't drawn and lets presses through at rest; it
   shows (and takes presses) once the content scrolls, and fades out a
   second later (plugins-themes-Adwaita#17). */
- (void) checkOverlayScrollers
{
  NSWindow *window;
  NSScrollView *scrollView;
  NSView *document;
  NSScroller *scroller;
  NSRect strip, clip;
  NSString *detail;
  NSView *hitRest, *hitShown, *hitFaded;
  NSUInteger inkRest, inkShown;
  BOOL under;

  if ([[NSUserDefaults standardUserDefaults] objectForKey: @"GnomeThemeOverlayScrollbars"] != nil
    && [[NSUserDefaults standardUserDefaults] boolForKey: @"GnomeThemeOverlayScrollbars"] == NO)
    {
      [self skip: @"overlay-scrollers" detail: @"GnomeThemeOverlayScrollbars is NO"];
      return;
    }
  window = [self windowWithFrame: NSMakeRect (60, 200, 300, 200) title: @"Probe Overlay Scrollers"];
  scrollView = AUTORELEASE ([[NSScrollView alloc] initWithFrame: NSMakeRect (10, 10, 280, 180)]);
  [scrollView setHasVerticalScroller: YES];
  [scrollView setBorderType: NSBezelBorder];
  document = AUTORELEASE ([[NSView alloc] initWithFrame: NSMakeRect (0, 0, 280, 1000)]);
  [document setAutoresizingMask: NSViewWidthSizable];
  [scrollView setDocumentView: document];
  [[window contentView] addSubview: scrollView];
  [window orderFront: nil];
  [window display];
  scroller = [scrollView verticalScroller];
  strip = [scroller frame];
  clip = [[scrollView contentView] frame];
  under = NSMaxX (clip) >= NSMaxX (strip) && NSMinX (strip) >= NSMinX (clip);
  hitRest = [scrollView hitTest: [[scrollView superview] convertPoint: NSMakePoint (NSMidX (strip), NSMidY (strip))
                                                             fromView: scrollView]];
  inkRest = QuirkProbeMeasure (QuirkProbeRender (scroller), QuirkProbeIsInk).count;

  {
    /* The slider shown: pixels in the scroller's strip that change from
       the scroll view at rest. (Counting ink over the whole scroll view
       counted its bezel, plugins-themes-Adwaita#58.) */
    NSBitmapImageRep *before = QuirkProbeRender (scrollView), *after;
    NSInteger x, y;
    NSUInteger a[3], b[3];

    [document scrollPoint: NSMakePoint (0, 300)];
    [window display];
    hitShown = [scrollView hitTest: [[scrollView superview] convertPoint: NSMakePoint (NSMidX (strip), NSMidY (strip))
                                                                fromView: scrollView]];
    after = QuirkProbeRender (scrollView);
    inkShown = 0;
    for (y = (NSInteger)NSMinY (strip); y < (NSInteger)NSMaxY (strip); y++)
      {
        for (x = (NSInteger)NSMinX (strip); x < (NSInteger)NSMaxX (strip); x++)
          {
            QuirkProbePixelAt (before, x, y, a);
            QuirkProbePixelAt (after, x, y, b);
            if (labs ((NSInteger)(a[0] + a[1] + a[2]) - (NSInteger)(b[0] + b[1] + b[2])) > 30)
              {
                inkShown++;
              }
          }
      }
  }

  [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.6]];
  hitFaded = [scrollView hitTest: [[scrollView superview] convertPoint: NSMakePoint (NSMidX (strip), NSMidY (strip))
                                                               fromView: scrollView]];
  [window orderOut: nil];

  /* Freed while its scroller is shown: its fade timer must stop with it
     (it messaged the freed views; plugins-themes-Adwaita#38). Run with
     NSZombieEnabled to see such messages. */
  {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    NSWindow *gone = [[NSWindow alloc] initWithContentRect: NSMakeRect (60, 200, 300, 200)
                                                 styleMask: NSTitledWindowMask
                                                   backing: NSBackingStoreBuffered
                                                     defer: NO];
    NSScrollView *goneView = [[NSScrollView alloc] initWithFrame: NSMakeRect (10, 10, 280, 180)];
    NSView *goneDocument = [[NSView alloc] initWithFrame: NSMakeRect (0, 0, 280, 1000)];

    [goneView setHasVerticalScroller: YES];
    [goneView setDocumentView: goneDocument];
    [[gone contentView] addSubview: goneView];
    [gone orderFront: nil];
    [gone display];
    [goneDocument scrollPoint: NSMakePoint (0, 300)];
    [gone orderOut: nil];
    [goneView removeFromSuperview];
    RELEASE (goneDocument);
    RELEASE (goneView);
    [gone setReleasedWhenClosed: NO];
    RELEASE (gone);
    [pool release];
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.6]];
  }

  detail = [NSString stringWithFormat: @"clip %@ %@ the scroller %@; a press on it at rest: %@, shown: %@, faded: %@; "
    @"slider ink %lu at rest, %lu shown",
    NSStringFromRect (clip), under ? @"runs under" : @"stops short of", NSStringFromRect (strip),
    [hitRest class], [hitShown class], [hitFaded class], (unsigned long)inkRest, (unsigned long)inkShown];
  if (under && hitRest != scroller && hitShown == scroller && hitFaded != scroller && inkRest == 0 && inkShown > 0)
    {
      [self pass: @"overlay-scrollers" detail: detail];
    }
  else
    {
      [self fail: @"overlay-scrollers" detail: detail];
    }
}

/* The window types the theme gives windows, as GTK's
   (_NET_WM_WINDOW_TYPE, plugins-themes-Adwaita#15). The probe's display
   has no window manager to set them for, so this asks the theme what it
   would set; run-mutter-check.sh reads one off a window. */
- (void) checkWindowTypes
{
  Class theme = NSClassFromString (@"GnomeTheme");
  Class panelClass = NSClassFromString (@"GSTTPanel");
  NSPopUpButton *popUp;
  NSWindow *toolTip, *alert;
  NSMenu *barMenu = nil;
  NSEnumerator *enumerator;
  NSMenuItem *item;
  NSString *wantedBarMenu, *detail;
  NSString *types[6];
  NSString *wanted[6];
  BOOL ok = YES;
  int i;

  if ([theme respondsToSelector: @selector(windowTypeForWindow:)] == NO || panelClass == Nil)
    {
      [self skip: @"window-types" detail: @"no +[GnomeTheme windowTypeForWindow:] or GSTTPanel"];
      return;
    }
  toolTip = [[panelClass alloc] initWithContentRect: NSMakeRect (0, 0, 100, 25)
                                          styleMask: NSBorderlessWindowMask
                                            backing: NSBackingStoreRetained
                                              defer: YES];
  popUp = [[NSPopUpButton alloc] initWithFrame: NSMakeRect (0, 0, 120, 30) pullsDown: NO];
  [popUp addItemWithTitle: @"One"];
  alert = NSGetAlertPanel (@"Title", @"Message", @"OK", nil, nil);
  enumerator = [[[NSApp mainMenu] itemArray] objectEnumerator];
  while (barMenu == nil && (item = [enumerator nextObject]) != nil)
    {
      barMenu = [item submenu];
    }
  if (NSInterfaceStyleForKey (@"NSMenuInterfaceStyle", nil) != NSWindows95InterfaceStyle)
    {
      wantedBarMenu = @"(libs-back's)";
    }
  else if ([[[NSUserDefaults standardUserDefaults] stringForKey: @"GnomeThemeMenuStyle"] isEqualToString: @"primary"])
    {
      wantedBarMenu = @"_NET_WM_WINDOW_TYPE_POPUP_MENU";
    }
  else
    {
      wantedBarMenu = @"_NET_WM_WINDOW_TYPE_DROPDOWN_MENU";
    }

  types[0] = [theme windowTypeForWindow: toolTip];
  wanted[0] = @"_NET_WM_WINDOW_TYPE_TOOLTIP";
  types[1] = [theme windowTypeForWindow: [[[popUp menu] menuRepresentation] window]];
  wanted[1] = @"_NET_WM_WINDOW_TYPE_POPUP_MENU";
  types[2] = [theme windowTypeForWindow: [[barMenu menuRepresentation] window]];
  wanted[2] = wantedBarMenu;
  types[3] = [theme windowTypeForWindow: alert];
  wanted[3] = @"_NET_WM_WINDOW_TYPE_DIALOG";
  types[4] = [theme windowTypeForWindow: [[GSDragView sharedDragView] window]];
  wanted[4] = @"_NET_WM_WINDOW_TYPE_DND";
  types[5] = [theme windowTypeForWindow: _controlsWindow];
  wanted[5] = @"(libs-back's)";
  for (i = 0; i < 6; i++)
    {
      if (types[i] == nil)
        {
          types[i] = @"(libs-back's)";
        }
      ok = ok && [types[i] isEqualToString: wanted[i]];
    }
  detail = [NSString stringWithFormat: @"tool tip %@, pop-up button's menu %@, menu bar's menu %@ (want %@), "
    @"alert %@, drag image %@, window %@",
    types[0], types[1], types[2], wanted[2], types[3], types[4], types[5]];
  if (ok)
    {
      [self pass: @"window-types" detail: detail];
    }
  else
    {
      [self fail: @"window-types" detail: detail];
    }
  NSReleaseAlertPanel (alert);
  RELEASE (popUp);
  RELEASE (toolTip);
}

- (void) checkFirstWindows: (NSTimer *)timer
{
  if ([[[NSUserDefaults standardUserDefaults] stringForKey: @"ProbeOnly"] isEqualToString: @"file-chooser"])
    {
      [self checkFileChooser];
      return;
    }
  if ([[[NSUserDefaults standardUserDefaults] stringForKey: @"ProbeOnly"] isEqualToString: @"menu-timing"])
    {
      [self checkMenuTiming];
      return;
    }
  if ([[[NSUserDefaults standardUserDefaults] stringForKey: @"ProbeOnly"] isEqualToString: @"scroller-drag"])
    {
      [self checkScrollerDrag];
      return;
    }
  if ([[[NSUserDefaults standardUserDefaults] stringForKey: @"ProbeOnly"] isEqualToString: @"context-menu"])
    {
      [self checkContextMenu];
      return;
    }
  if ([[[NSUserDefaults standardUserDefaults] stringForKey: @"ProbeOnly"] isEqualToString: @"context-menu-demo"])
    {
      [self showContextMenuDemo];
      return;
    }
  /* -ProbeOnly text-scaling, for the runs with GNOME's Large Text
     (make check-text-scaling). */
  if ([[[NSUserDefaults standardUserDefaults] stringForKey: @"ProbeOnly"] isEqualToString: @"text-scaling"])
    {
      [self checkTextScaling];
      [self finish];
      return;
    }
  /* -ProbeOnly nib-metrics, for the runs with -GnomeThemeMetrics set
     (make check-nib-metrics). */
  if ([[[NSUserDefaults standardUserDefaults] stringForKey: @"ProbeOnly"] isEqualToString: @"nib-metrics"])
    {
      [self checkNibMetrics];
      [self finish];
      return;
    }
  /* -ProbeOnly header-bar: the header bar's checks alone, for the dark and
     high contrast runs (the other checks assume the light palette). */
  if ([[[NSUserDefaults standardUserDefaults] stringForKey: @"ProbeOnly"] isEqualToString: @"header-bar"])
    {
      [self checkHeaderBar];
  [self checkHeaderBarToolbar];
  [self checkHeaderBarToolbarItemClick];
  [self checkHeaderBarToolbarItemDrag];
  [self checkHeaderBarDocumentTitle];
  [self checkHeaderBarToolbarLive];
      [self checkSegmentedSelection];
      [self checkMenuSeparatorAndShortcut];
      [self checkTemplateImages];
  [self checkOverlayScrollers];
  [self checkSwitch];
  [self checkControlColors];
  [self checkSliderKnob];
  [self checkScrollViewFrame];
  [self checkPopUpChevron];
      [self finish];
      return;
    }
  [self saveWindow: _controlsWindow named: @"controls"];
  [self saveWindow: _toolbarWindow named: @"toolbar"];
  [self saveWindow: _tableWindow named: @"tables"];
  [self checkThemeDomain];
  [self checkTextWidth];
  [self checkTextScaling];
  [self checkImageFreeButton];
  [self checkShortcutLabels];
  [self checkCustomBackgroundField];
  [self checkInlineMenuRow];
  [self checkSizedButtons];
  [self checkFixedButtons];
  [self checkSteppers];
  [self checkColorWell];
  [self checkLabels];
  [self checkToolbar];
  [self checkTables];
  [self checkMenuBar];
  [self checkMenuBarClick];
  [self checkToolbarEdges];
  [self checkToolbarHover];
  [self checkPopUpButton];
  [self checkPopUpClick];
  [self checkButtonFocusRing];
  [self checkCheckboxGap];
  [self checkTableDensity];
  [self checkTabView];
  [self checkToolbarDisplayMode];
  [self checkToolbarRowHeight];
  [self checkToolbarViewItemWidth];
  [self checkSegmentedSelection];
  [self checkMenuSeparatorAndShortcut];
  [self checkApplicationMenuPosition];
  [self checkMenuBarOverflow];
  [self checkCocoaApplicationMenu];
  [self checkGormControls];
  [self checkMetricsMode];
  [self checkNibMetrics];
  [self checkPrimaryMenu];
  [self checkHeaderBar];
  [self checkHeaderBarToolbar];
  [self checkHeaderBarToolbarItemClick];
  [self checkHeaderBarToolbarItemDrag];
  [self checkHeaderBarDocumentTitle];
  [self checkHeaderBarToolbarLive];
  [self checkFonts];
  [self checkToolTip];
  [self checkHiddenWindows];
  [self checkWindowTypes];
  [self checkTemplateImages];
  [self checkOverlayScrollers];
  [self checkSwitch];
  [self checkControlColors];
  [self checkSliderKnob];
  [self checkScrollViewFrame];
  [self checkPopUpChevron];

  /* Auxiliary windows made after launch: a Settings window, a window whose
     delegate turns the menu bar off, and a Preferences window whose
     delegate keeps it. */
  _latePrefsWindow = [self windowWithFrame: NSMakeRect (800, 560, 200, 80) title: @"Settings\u2026"];
  [_latePrefsWindow makeKeyAndOrderFront: nil];
  _optOutWindow = [self windowWithFrame: NSMakeRect (800, 680, 200, 80) title: @"Inspector"];
  [_optOutWindow setDelegate: self];
  [_optOutWindow makeKeyAndOrderFront: nil];
  _optInWindow = [self windowWithFrame: NSMakeRect (1020, 560, 200, 80) title: @"Preferences"];
  [_optInWindow setDelegate: self];
  [_optInWindow makeKeyAndOrderFront: nil];

  _lateWindow = [self windowWithFrame: NSMakeRect (480, 560, 300, 100) title: @"QuirkProbe Late Window"];
  [_lateWindow makeKeyAndOrderFront: nil];
  [self after: QuirkProbeSettleDelay perform: @selector(checkLateWindow:)];
}

/* The menu bar answer for the windows the probe is the delegate of. */
- (BOOL) windowShouldShowMenuBar: (NSWindow *)window
{
  return window != _optOutWindow;
}

/* GNOME apps keep their menus out of auxiliary windows. */
- (void) checkAuxiliaryWindowMenus
{
  NSMenu *mainMenu = [NSApp mainMenu];
  NSString *detail = [NSString stringWithFormat: @"menu bar on: Preferences at launch %@, Settings… later %@, "
    @"delegate says no %@, Preferences whose delegate says yes %@",
    [_launchPrefsWindow menu] == mainMenu ? @"yes" : @"no",
    [_latePrefsWindow menu] == mainMenu ? @"yes" : @"no",
    [_optOutWindow menu] == mainMenu ? @"yes" : @"no",
    [_optInWindow menu] == mainMenu ? @"yes" : @"no"];

  if (NSInterfaceStyleForKey (@"NSMenuInterfaceStyle", nil) != NSWindows95InterfaceStyle)
    {
      [self skip: @"auxiliary-window-no-menu" detail: @"needs -NSMenuInterfaceStyle NSWindows95InterfaceStyle"];
    }
  else if ([_launchPrefsWindow menu] == nil && [_latePrefsWindow menu] == nil
    && [_optOutWindow menu] == nil && [_optInWindow menu] == mainMenu)
    {
      [self pass: @"auxiliary-window-no-menu" detail: detail];
    }
  else
    {
      [self fail: @"auxiliary-window-no-menu" detail: detail];
    }
}

- (void) checkLateWindow: (NSTimer *)timer
{
  [self checkAuxiliaryWindowMenus];
  [self saveWindow: _launchPrefsWindow named: @"preferences-window"];
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
  QuirkProbeInk headingInk = { 0 };
  CGFloat leftGap = 0.0, rightGap = 0.0;
  BOOL centred = NO;
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
  /* Measured from the drawing, not -alignment: libs-gui after 0.32 numbers
     NSTextAlignment differently, so the constants this probe was built with
     may mean another alignment to the libs-gui it runs with. */
  if (heading != nil)
    {
      headingInk = QuirkProbeTextInk (heading);
      leftGap = headingInk.minX;
      rightGap = NSWidth ([heading bounds]) - headingInk.minX - headingInk.width;
      centred = headingInk.count > 0 && fabs (leftGap - rightGap) <= 3.0;
    }
  detail = [NSString stringWithFormat: @"%lu icons, %lu lines; Remove %@, Cancel %@; heading %@ (ink %.0f from the left, %.0f from the right)",
    (unsigned long)visibleIcons, (unsigned long)visibleLines,
    NSStringFromRect ([remove frame]), NSStringFromRect ([cancel frame]),
    centred ? @"centred" : @"not centred", leftGap, rightGap];
  if (remove != nil && cancel != nil && visibleIcons == 0 && visibleLines == 0
    && NSWidth ([remove frame]) == NSWidth ([cancel frame])
    && NSMinY ([remove frame]) == NSMinY ([cancel frame])
    && NSMinX ([remove frame]) > NSMaxX ([cancel frame])
    && centred)
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
