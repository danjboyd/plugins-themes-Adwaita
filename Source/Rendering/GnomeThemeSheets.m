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

/* GnomeThemeSheets.m: how a sheet stands out from its window.

   libadwaita has no sheets, so the theme gives them a look of its own
   (ask #8049): while a sheet is open on a window, the window's content
   is dimmed behind it and the sheet casts a soft shadow, as libadwaita's
   dialogs dim the window behind them.

   An attached sheet is a child X window of its parent, and X does not
   blend a child window over its parent, so neither the dimming nor the
   shadow can come from the sheet. The parent draws both: an overlay view
   above its content view, from NSWindowWillBeginSheetNotification to
   NSWindowDidEndSheetNotification. The sheet's own window covers its
   rectangle, so what shows of the overlay is the dimmed content and the
   shadow around the sheet. libs-gui tells the theme each step of the
   slide (-sheet:revealed:inWindow:), so the dim fades in with it and the
   shadow follows the part of the sheet that is out. A sheet that went
   the old way (a separate window) gets the dim whole and no shadow. */

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSTheme.h>
#import "../GnomeTheme.h"
#import "../Settings/GnomeThemeSettings.h"

@interface GnomeThemeSheetOverlay : NSView
{
  NSWindow *_parent; /* not retained: the overlay is its subview */
@public
  CGFloat _shown;    /* how much of an attached sheet is out, 0 to 1;
			below 0 until the sheet attaches (or if it never
			does, shown the old way) */
}
- (id) initWithParent: (NSWindow *)parent;
@end

@interface GnomeThemeSheetObserver : NSObject
@end

static GnomeThemeSheetObserver *observer = nil;

static BOOL
GnomeThemeSheetDark (void)
{
  GSTheme *theme = [GSTheme theme];

  return [theme isKindOfClass: [GnomeTheme class]]
    && [[(GnomeTheme *)theme settings] prefersDarkAppearance];
}

static CGFloat
GnomeThemeSheetCornerRadius (void)
{
  CGFloat radius = [[NSUserDefaults standardUserDefaults]
    floatForKey: @"GSBackWindowCornerRadius"];

  return radius > 0 ? radius : 12;
}

/* libs-gui with attached sheets has these; older ones don't. */
@interface GSTheme (GnomeThemeSheetAttachment)
- (NSRect) sheetAttachmentRectForWindow: (NSWindow *)window;
@end
@interface NSObject (GnomeThemeSheetDelegate)
- (NSRect) window: (NSWindow *)window willPositionSheet: (NSWindow *)sheet
	usingRect: (NSRect)rect;
@end

/* Where an attached sheet sits in its parent, in the parent's base
   coordinates, placed as libs-gui places it: centred on the attachment
   rect (the delegate's, if it gives one), its top on that rect's line.
   The sheet's own frame gives only its size: while the backend slides it,
   its position there follows the moving X window. */
static NSRect
GnomeThemeSheetRectInParent (NSWindow *sheet, NSWindow *parent)
{
  GSTheme *theme = [GSTheme theme];
  NSSize size = [sheet frame].size;
  id delegate = [parent delegate];
  NSRect anchor;

  if ([theme respondsToSelector: @selector(sheetAttachmentRectForWindow:)] == NO)
    {
      NSRect frame = [sheet frame];
      NSPoint origin = [parent convertScreenToBase: frame.origin];

      return NSMakeRect (origin.x, origin.y, size.width, size.height);
    }
  anchor = [theme sheetAttachmentRectForWindow: parent];
  if ([delegate respondsToSelector:
		  @selector(window:willPositionSheet:usingRect:)])
    {
      anchor = [delegate window: parent willPositionSheet: sheet
		      usingRect: anchor];
    }
  return NSMakeRect (NSMinX (anchor) + (NSWidth (anchor) - size.width) / 2,
		     NSMinY (anchor) - size.height, size.width, size.height);
}

NSBezierPath *
GnomeThemeSheetOutline (NSRect rect, CGFloat radius)
{
  NSBezierPath *path = [NSBezierPath bezierPath];
  CGFloat r = MAX (0, MIN (radius, MIN (NSWidth (rect), NSHeight (rect)) / 2));

  [path moveToPoint: NSMakePoint (NSMinX (rect), NSMaxY (rect))];
  [path lineToPoint: NSMakePoint (NSMinX (rect), NSMinY (rect) + r)];
  if (r > 0)
    [path appendBezierPathWithArcWithCenter:
            NSMakePoint (NSMinX (rect) + r, NSMinY (rect) + r)
				     radius: r
				 startAngle: 180
				   endAngle: 270];
  [path lineToPoint: NSMakePoint (NSMaxX (rect) - r, NSMinY (rect))];
  if (r > 0)
    [path appendBezierPathWithArcWithCenter:
            NSMakePoint (NSMaxX (rect) - r, NSMinY (rect) + r)
				     radius: r
				 startAngle: 270
				   endAngle: 360];
  [path lineToPoint: NSMakePoint (NSMaxX (rect), NSMaxY (rect))];
  [path closePath];
  return path;
}

@implementation GnomeThemeSheetOverlay

- (id) initWithParent: (NSWindow *)parent
{
  NSView *content = [parent contentView];

  self = [super initWithFrame: [content frame]];
  if (self != nil)
    {
      _parent = parent;
      _shown = -1;
      [self setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
    }
  return self;
}

/* Clicks go where they went: the modal session already keeps them from
   the parent. */
- (NSView *) hitTest: (NSPoint)point
{
  return nil;
}

- (BOOL) isOpaque
{
  return NO;
}

- (void) drawRect: (NSRect)dirty
{
  NSWindow *sheet = [_parent attachedSheet];
  BOOL dark = GnomeThemeSheetDark ();
  NSRect bounds = [self bounds];

  /* The dim fades in and out with the slide; a sheet shown the old way
     gets it whole. */
  CGFloat amount = _shown < 0 ? 1 : _shown;

  if (amount <= 0)
    {
      return;
    }
  [[NSColor colorWithCalibratedWhite: 0 alpha: (dark ? 0.24 : 0.12) * amount] set];
  NSRectFillUsingOperation (bounds, NSCompositeSourceOver);
  /* The shadow, only for a sheet inside the window (an attached one): a
     light, tight one, as Adwaita draws them (a few faint layers a little
     below it, about a tenth dark at its edge), then a fine edge. The sheet's corners are
     square at the top, where it meets the header bar, and rounded at
     the bottom (the backend cuts those out of its window). */
  if (sheet != nil && _shown > 0)
    {
      NSRect rect = [self convertRect: GnomeThemeSheetRectInParent (sheet, _parent)
			     fromView: nil];
      CGFloat radius = MIN (GnomeThemeSheetCornerRadius (),
			    MIN (NSWidth (rect), NSHeight (rect)) / 2);
      CGFloat top = NSMaxY (rect);
      int i, layers = 6;

      if (NSContainsRect (NSInsetRect (bounds, -1, -1), rect) == NO)
	{
	  return;
	}
      /* What is out of the sheet so far: it slides down from under the
	 header bar, so its top stays put and its bottom moves. */
      rect.origin.y = NSMaxY (rect) - _shown * NSHeight (rect);
      rect.size.height = _shown * NSHeight (rect);
      if (NSHeight (rect) < 1)
	{
	  return;
	}
      [NSGraphicsContext saveGraphicsState];
      for (i = layers; i > 0; i--)
	{
	  CGFloat grow = i * 1.3;
	  NSRect layer = NSMakeRect (NSMinX (rect) - grow,
				     NSMinY (rect) - grow - 1,
				     NSWidth (rect) + 2 * grow,
				     top - (NSMinY (rect) - grow - 1));

	  [[NSColor colorWithCalibratedWhite: 0
				       alpha: (dark ? 0.03 : 0.016)]
	    set];
	  [GnomeThemeSheetOutline (layer, radius + grow) fill];
	}
      [[NSColor colorWithCalibratedWhite: 0 alpha: dark ? 0.5 : 0.12] set];
      [GnomeThemeSheetOutline (NSInsetRect (rect, -0.5, -0.5), radius + 0.5)
	stroke];
      [NSGraphicsContext restoreGraphicsState];
    }
}
@end

@implementation GnomeThemeSheetObserver

static GnomeThemeSheetOverlay *
GnomeThemeSheetOverlayOf (NSWindow *parent)
{
  NSEnumerator *e = [[[[parent contentView] superview] subviews]
		      objectEnumerator];
  NSView *view;

  while ((view = [e nextObject]) != nil)
    {
      if ([view isKindOfClass: [GnomeThemeSheetOverlay class]])
	{
	  return (GnomeThemeSheetOverlay *)view;
	}
    }
  return nil;
}

- (void) willBeginSheet: (NSNotification *)notification
{
  NSWindow *parent = [notification object];
  NSView *frameView = [[parent contentView] superview];
  GnomeThemeSheetOverlay *overlay;

  if (frameView == nil || GnomeThemeSheetOverlayOf (parent) != nil)
    {
      return;
    }
  overlay = [[GnomeThemeSheetOverlay alloc] initWithParent: parent];
  [frameView addSubview: overlay positioned: NSWindowAbove relativeTo: nil];
  /* An attached sheet's steps come through -sheet:revealed:inWindow:,
     the first (0) before anything is drawn; a sheet shown the old way gets
     the dim when the window is next drawn. */
  [overlay setNeedsDisplay: YES];
  RELEASE (overlay);
}

- (void) didEndSheet: (NSNotification *)notification
{
  NSWindow *parent = [notification object];
  GnomeThemeSheetOverlay *overlay = GnomeThemeSheetOverlayOf (parent);

  if (overlay != nil)
    {
      [overlay removeFromSuperview];
      [[[parent contentView] superview] setNeedsDisplay: YES];
    }
}
@end

@implementation GnomeTheme (Sheets)

/* Each step of an attached sheet's slide (libs-gui calls it before the
   backend shows the step): the dim and shadow are drawn for it now, into
   the parent's buffer, which the backend shows with the sheet. */
- (void) sheet: (NSWindow *)sheet
      revealed: (CGFloat)fraction
      inWindow: (NSWindow *)parent
{
  GnomeThemeSheetOverlay *overlay = GnomeThemeSheetOverlayOf (parent);

  if (overlay == nil)
    {
      return;
    }
  overlay->_shown = MAX (0, MIN (1, fraction));
  [overlay setNeedsDisplay: YES];
  [parent displayIfNeeded];
}
@end

void
GnomeThemeSheetsStart (void)
{
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

  if (observer != nil)
    {
      return;
    }
  observer = [GnomeThemeSheetObserver new];
  [center addObserver: observer
	     selector: @selector(willBeginSheet:)
		 name: NSWindowWillBeginSheetNotification
	       object: nil];
  [center addObserver: observer
	     selector: @selector(didEndSheet:)
		 name: NSWindowDidEndSheetNotification
	       object: nil];
}

void
GnomeThemeSheetsStop (void)
{
  NSEnumerator *e;
  NSWindow *window;

  if (observer != nil)
    {
      [[NSNotificationCenter defaultCenter] removeObserver: observer];
      DESTROY (observer);
    }
  /* A sheet open while the theme goes: its DidEndSheet will come to no
     one, and nothing else takes the overlay out of its window (libs-gui
     keeps the frame view on a theme switch), so it would stay dimmed. */
  e = [[NSApp windows] objectEnumerator];
  while ((window = [e nextObject]) != nil)
    {
      GnomeThemeSheetOverlay *overlay = GnomeThemeSheetOverlayOf (window);

      if (overlay != nil)
	{
	  [overlay removeFromSuperview];
	  [[[window contentView] superview] setNeedsDisplay: YES];
	}
    }
}
