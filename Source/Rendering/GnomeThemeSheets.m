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
   shadow around the sheet. A sheet that went the old way (a separate
   window) leaves the shadow out; the window is still dimmed. */

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSTheme.h>
#import "../GnomeTheme.h"
#import "../Settings/GnomeThemeSettings.h"

@interface GnomeThemeSheetOverlay : NSView
{
  NSWindow *_parent; /* not retained: the overlay is its subview */
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

/* The sheet's frame in the parent's base coordinates. */
static NSRect
GnomeThemeSheetRectInParent (NSWindow *sheet, NSWindow *parent)
{
  NSRect frame = [sheet frame];
  NSPoint origin = [parent convertScreenToBase: frame.origin];

  return NSMakeRect (origin.x, origin.y, NSWidth (frame), NSHeight (frame));
}

@implementation GnomeThemeSheetOverlay

- (id) initWithParent: (NSWindow *)parent
{
  NSView *content = [parent contentView];

  self = [super initWithFrame: [content frame]];
  if (self != nil)
    {
      _parent = parent;
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

  [[NSColor colorWithCalibratedWhite: 0 alpha: dark ? 0.36 : 0.22] set];
  NSRectFillUsingOperation (bounds, NSCompositeSourceOver);
  /* The shadow, only for a sheet inside the window (an attached one): soft
     layers around and below it, then a fine edge. The sheet's corners are
     rounded (the backend cuts them out of its window), and the layers
     start below the top corners, so the gaps there show only the dim. */
  if (sheet != nil && [sheet isVisible])
    {
      NSRect rect = [self convertRect: GnomeThemeSheetRectInParent (sheet, _parent)
			     fromView: nil];
      CGFloat radius = MIN (GnomeThemeSheetCornerRadius (),
			    MIN (NSWidth (rect), NSHeight (rect)) / 2);
      CGFloat top = NSMaxY (rect) - radius;
      int i, layers = 10;

      if (NSContainsRect (NSInsetRect (bounds, -1, -1), rect) == NO)
	{
	  return;
	}
      [NSGraphicsContext saveGraphicsState];
      for (i = layers; i > 0; i--)
	{
	  CGFloat grow = i * 1.6;
	  NSRect layer = NSMakeRect (NSMinX (rect) - grow,
				     NSMinY (rect) - grow - 3,
				     NSWidth (rect) + 2 * grow,
				     top - (NSMinY (rect) - grow - 3));

	  [[NSColor colorWithCalibratedWhite: 0
				       alpha: (dark ? 0.05 : 0.035)]
	    set];
	  [[NSBezierPath bezierPathWithRoundedRect: layer
					   xRadius: radius + grow
					   yRadius: radius + grow] fill];
	}
      [[NSColor colorWithCalibratedWhite: 0 alpha: dark ? 0.6 : 0.16] set];
      [[NSBezierPath bezierPathWithRoundedRect: NSInsetRect (rect, -0.5, -0.5)
				       xRadius: radius + 0.5
				       yRadius: radius + 0.5] stroke];
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
  NSWindow *sheet = [parent attachedSheet];
  NSView *frameView = [[parent contentView] superview];
  GnomeThemeSheetOverlay *overlay;

  if (frameView == nil || GnomeThemeSheetOverlayOf (parent) != nil)
    {
      return;
    }
  overlay = [[GnomeThemeSheetOverlay alloc] initWithParent: parent];
  [frameView addSubview: overlay positioned: NSWindowAbove relativeTo: nil];
  RELEASE (overlay);
  /* The sheet is framed when it attaches and becomes key just before it
     slides in: draw the shadow where it will be, before the slide. */
  if (sheet != nil)
    {
      [[NSNotificationCenter defaultCenter]
	addObserver: self
	   selector: @selector(sheetPlaced:)
	       name: NSWindowDidBecomeKeyNotification
	     object: sheet];
    }
  [overlay setNeedsDisplay: YES];
  [parent displayIfNeeded];
}

- (void) sheetPlaced: (NSNotification *)notification
{
  NSWindow *parent = [[notification object] parentWindow];
  GnomeThemeSheetOverlay *overlay = GnomeThemeSheetOverlayOf (parent);

  [overlay setNeedsDisplay: YES];
  [parent displayIfNeeded];
}

- (void) didEndSheet: (NSNotification *)notification
{
  NSWindow *parent = [notification object];
  GnomeThemeSheetOverlay *overlay = GnomeThemeSheetOverlayOf (parent);

  [[NSNotificationCenter defaultCenter]
    removeObserver: self name: NSWindowDidBecomeKeyNotification object: nil];
  if (overlay != nil)
    {
      [overlay removeFromSuperview];
      [[[parent contentView] superview] setNeedsDisplay: YES];
    }
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
  if (observer != nil)
    {
      [[NSNotificationCenter defaultCenter] removeObserver: observer];
      DESTROY (observer);
    }
}
