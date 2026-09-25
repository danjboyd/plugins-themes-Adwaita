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

/* GNOME's primary menu instead of a menu bar (GnomeThemeMenuStyle =
   "primary"). The window's menu bar becomes a single ☰ button: in the
   header bar when the theme draws one (GnomeThemeHeaderBar.m), otherwise at
   the end of the toolbar when the window shows one (the toolbar is narrowed
   to make room), otherwise alone in a slim bar styled like a toolbar. Clicking it
   shows a copy of the main menu: its menus, then the application menu's
   items (About, Preferences, Quit), as GNOME's primary menu orders them.
   The app's menu itself is untouched, so key equivalents, validation and
   Services keep working; the copy is made each time it opens, so it shows
   the menu as it is then. */

#import "../GnomeTheme.h"
#import "../Settings/GnomeThemeMetrics.h"

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSTheme.h>
#import <objc/runtime.h>

/* libadwaita header bar buttons: 34px, with 6px to the window's edge. */
static const CGFloat GnomeThemePrimaryButtonSize = 34.0;
static const CGFloat GnomeThemePrimaryButtonMargin = 6.0;
/* The bar that holds the button when there's no toolbar. */
static const CGFloat GnomeThemePrimaryBarHeight = 40.0;

/* On a window: the menu bar height it was given (see -menuHeightForWindow:).
   On a toolbar view: its ☰ button. */
static char GnomeThemePrimaryBarHeightKey;
static char GnomeThemePrimaryToolbarButtonKey;

@interface NSWindow (GnomeThemePrimaryMenuPrivate)
- (id) windowView;
- (void) _setMenu: (NSMenu *)menu;
@end

@interface NSView (GnomeThemePrimaryMenuDecoration)
- (void) addMenuView: (NSMenuView *)menuView;
- (NSMenuView *) removeMenuView;
- (void) updateRects;
@end

@interface NSToolbar (GnomeThemePrimaryMenuPrivate)
- (NSView *) _toolbarView;
@end

BOOL
GnomeThemeUsesPrimaryMenu(void)
{
  NSString *style = [[NSUserDefaults standardUserDefaults] stringForKey: @"GnomeThemeMenuStyle"];
  id declared = [[[NSBundle mainBundle] infoDictionary] objectForKey: @"GnomeThemeMenuStyle"];

  /* The user's default, then the app's own choice in its Info.plist. */
  if (style == nil && [declared isKindOfClass: [NSString class]])
    {
      style = declared;
    }

  return style != nil && [style caseInsensitiveCompare: @"primary"] == NSOrderedSame;
}

static BOOL
GnomeThemeWindowShowsToolbar(NSWindow *window)
{
  NSToolbar *toolbar = [window toolbar];

  return toolbar != nil && [toolbar isVisible];
}

/* The height of the bar that holds the ☰: none when the header bar or the
   toolbar holds it. */
static CGFloat
GnomeThemePrimaryBarHeightForWindow(NSWindow *window)
{
  if (GnomeThemeUsesHeaderBar () || GnomeThemeWindowShowsToolbar (window))
    {
      return 0.0;
    }
  return GnomeThemePrimaryBarHeight;
}

static NSMenu *
GnomeThemeCopyPrimaryMenu(void)
{
  NSMenu *mainMenu = [NSApp mainMenu];
  NSMenu *primary = [[NSMenu alloc] initWithTitle: @""];
  NSEnumerator *enumerator = [[mainMenu itemArray] objectEnumerator];
  NSMenuItem *item;
  NSMenuItem *appItem = nil;

  while ((item = [enumerator nextObject]) != nil)
    {
      NSMenuItem *copy;

      if (GnomeThemeIsApplicationMenuItem (item))
        {
          appItem = item;
          continue;
        }
      copy = [item copy];
      [primary addItem: copy];
      RELEASE (copy);
    }
  if ([[appItem submenu] numberOfItems] > 0)
    {
      if ([primary numberOfItems] > 0)
        {
          [primary addItem: [NSMenuItem separatorItem]];
        }
      enumerator = [[[appItem submenu] itemArray] objectEnumerator];
      while ((item = [enumerator nextObject]) != nil)
        {
          NSMenuItem *copy = [item copy];

          [primary addItem: copy];
          RELEASE (copy);
        }
    }
  /* Copies share the originals' targets, actions and states; adding them
     links their copied submenus to the copy. */
  return AUTORELEASE (primary);
}

/* The ☰ button: a flat header bar button, drawn on the toolbar's background
   with the toolbar's bottom edge, so it reads as part of the toolbar or bar
   it sits in. */
@interface GnomeThemePrimaryMenuButton : NSView
{
  NSTrackingRectTag _tracking;
  BOOL _hover;
  BOOL _pressed;
  BOOL _drawsBar;
}
- (void) setDrawsBar: (BOOL)flag;
@end

@implementation GnomeThemePrimaryMenuButton

- (id) initWithFrame: (NSRect)frame
{
  if ((self = [super initWithFrame: frame]) != nil)
    {
      _drawsBar = YES;
      [self setToolTip: @"Main Menu"];
    }
  return self;
}

- (void) setDrawsBar: (BOOL)flag
{
  _drawsBar = flag;
  [self setNeedsDisplay: YES];
}

- (NSRect) buttonRect
{
  NSRect bounds = [self bounds];

  return NSMakeRect (NSMaxX (bounds) - GnomeThemePrimaryButtonMargin - GnomeThemePrimaryButtonSize,
                     floor (NSMidY (bounds) - GnomeThemePrimaryButtonSize / 2.0),
                     GnomeThemePrimaryButtonSize, GnomeThemePrimaryButtonSize);
}

- (void) updateTracking
{
  if (_tracking != 0)
    {
      [self removeTrackingRect: _tracking];
      _tracking = 0;
    }
  if ([self window] != nil)
    {
      _tracking = [self addTrackingRect: [self buttonRect] owner: self userData: NULL assumeInside: NO];
    }
}

- (void) viewDidMoveToWindow
{
  [super viewDidMoveToWindow];
  [self updateTracking];
}

- (void) setFrame: (NSRect)frame
{
  [super setFrame: frame];
  [self updateTracking];
}

- (void) mouseEntered: (NSEvent *)event
{
  _hover = YES;
  [self setNeedsDisplay: YES];
}

- (void) mouseExited: (NSEvent *)event
{
  _hover = NO;
  [self setNeedsDisplay: YES];
}

- (void) drawRect: (NSRect)rect
{
  GSTheme *theme = [GSTheme theme];
  NSRect bounds = [self bounds];
  NSColor *background = [theme toolbarBackgroundColor];
  NSColor *textColor = [NSColor controlTextColor];
  NSRect button = [self buttonRect];

  if (_drawsBar)
    {
      [background set];
      NSRectFill (bounds);
      [[theme toolbarBorderColor] set];
      NSRectFill (NSMakeRect (NSMinX (bounds), [self isFlipped] ? NSMaxY (bounds) - 1.0 : NSMinY (bounds),
                              NSWidth (bounds), 1.0));
    }
  /* libadwaita's flat buttons: the text colour at 7% under the pointer,
     16% pressed, 6px corners (as the toolbar's buttons). */
  if (_drawsBar == NO && GnomeThemeUsesHeaderBar ())
    {
      /* In the header bar: on the window's background, dimmed with the
         title when the window isn't focused. */
      background = [NSColor windowBackgroundColor];
      textColor = GnomeThemeHeaderBarTextColor ([self window]);
    }
  if (_hover || _pressed)
    {
      NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect: button xRadius: 6.0 yRadius: 6.0];
      CGFloat fraction = _pressed ? 0.16 : 0.07;

      [[background blendedColorWithFraction: fraction ofColor: textColor] set];
      [path fill];
    }
  GnomeThemeDrawApplicationMenuIcon (button, textColor);
}

- (BOOL) acceptsFirstMouse: (NSEvent *)event
{
  return YES;
}

/* Shows the primary menu under the button and tracks it until a click
   picks an item or lands outside it. Tracking starts from a fresh press:
   since libs-gui 0.32 (commit 82717eefe) any mouse up ends menu tracking,
   so the release of the click that opened the menu would close it again.
   Between clicks the menu follows the pointer, submenus included. */
- (void) showPrimaryMenu
{
  NSMenu *primary = GnomeThemeCopyPrimaryMenu ();
  NSMenuView *menuView = [primary menuRepresentation];
  NSRect button = [self convertRect: [self buttonRect] toView: nil];
  NSPoint corner = [[self window] convertBaseToScreen: NSMakePoint (NSMaxX (button), NSMinY (button))];
  NSWindow *menuWindow;
  NSEvent *press;

  if ([primary numberOfItems] == 0)
    {
      return;
    }
  /* Shown as a context menu is, then moved under the button, right edges
     aligned, as GNOME's primary menu popover sits. */
  [primary displayTransient];
  menuWindow = [menuView window];
  [menuWindow setFrameOrigin: NSMakePoint (corner.x - NSWidth ([menuWindow frame]),
                                           corner.y - NSHeight ([menuWindow frame]))];
  press = [NSEvent mouseEventWithType: NSLeftMouseDown
                             location: [menuWindow mouseLocationOutsideOfEventStream]
                        modifierFlags: 0
                            timestamp: [[NSApp currentEvent] timestamp]
                         windowNumber: [menuWindow windowNumber]
                              context: nil
                          eventNumber: 0
                           clickCount: 1
                             pressure: 1.0];
  [menuView mouseDown: press];
  [primary closeTransient];
}

/* As a GTK menu button: pressed while the pointer is on it, and the menu
   opens when the click is released there. */
- (void) mouseDown: (NSEvent *)event
{
  NSEvent *current = event;

  if (NSPointInRect ([self convertPoint: [event locationInWindow] fromView: nil], [self buttonRect]) == NO)
    {
      return;
    }
  _pressed = YES;
  [self display];
  while ([current type] != NSLeftMouseUp)
    {
      BOOL inside;

      current = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask
                                           untilDate: [NSDate distantFuture]
                                              inMode: NSEventTrackingRunLoopMode
                                             dequeue: YES];
      inside = NSPointInRect ([self convertPoint: [current locationInWindow] fromView: nil], [self buttonRect]);
      if (inside != _pressed)
        {
          _pressed = inside;
          [self display];
        }
    }
  if (_pressed)
    {
      [self showPrimaryMenu];
    }

  _pressed = NO;
  _hover = NSPointInRect ([self convertPoint: [[self window] mouseLocationOutsideOfEventStream] fromView: nil],
                          [self buttonRect]);
  [self setNeedsDisplay: YES];
}

@end

NSView *
GnomeThemeNewHeaderBarMenuButton(void)
{
  GnomeThemePrimaryMenuButton *button = [[GnomeThemePrimaryMenuButton alloc] initWithFrame: NSZeroRect];

  [button setDrawsBar: NO];
  return button;
}

/* The ☰ button's width in a toolbar. */
static CGFloat
GnomeThemePrimaryToolbarButtonWidth(void)
{
  return GnomeThemePrimaryButtonSize + 2.0 * GnomeThemePrimaryButtonMargin;
}

/* Puts a toolbar view's ☰ button beside it (the toolbar is narrowed to
   leave room, see -[GSToolbarView setFrame:]), or takes it away. */
static void
GnomeThemePlaceToolbarButton(NSView *toolbarView)
{
  GnomeThemePrimaryMenuButton *button = objc_getAssociatedObject (toolbarView, &GnomeThemePrimaryToolbarButtonKey);
  NSWindow *window = [toolbarView window];
  NSView *superview = [toolbarView superview];
  BOOL wanted = (window != nil && superview != nil && GnomeThemeUsesPrimaryMenu ()
                 && GnomeThemeUsesHeaderBar () == NO
                 && [window menu] != nil && GnomeThemeWindowShowsToolbar (window));
  NSRect frame = [toolbarView frame];

  if (wanted == NO)
    {
      [button removeFromSuperview];
      return;
    }
  if (button == nil)
    {
      button = AUTORELEASE ([[GnomeThemePrimaryMenuButton alloc] initWithFrame: NSZeroRect]);
      objc_setAssociatedObject (toolbarView, &GnomeThemePrimaryToolbarButtonKey, button,
                                OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
  [button setFrame: NSMakeRect (NSMaxX (frame), NSMinY (frame),
                                NSMaxX ([superview bounds]) - NSMaxX (frame), NSHeight (frame))];
  [button setAutoresizingMask: NSViewMinXMargin | ([toolbarView autoresizingMask] & (NSViewMinYMargin | NSViewMaxYMargin))];
  if ([button superview] != superview)
    {
      [superview addSubview: button];
    }
  [button setNeedsDisplay: YES];
}

/* Re-lays out a window's menu bar and toolbar for the primary menu: the
   bar's height depends on whether the toolbar shows (the ☰ is in the
   toolbar then), so re-add the menu view when that changed. */
static void
GnomeThemeUpdatePrimaryMenuPlacement(NSWindow *window)
{
  NSView *windowView = [window windowView];
  NSToolbar *toolbar = [window toolbar];
  NSNumber *given = objc_getAssociatedObject (window, &GnomeThemePrimaryBarHeightKey);
  CGFloat wanted = GnomeThemePrimaryBarHeightForWindow (window);

  if ([window menu] != nil && given != nil && [given floatValue] != wanted
    && [windowView respondsToSelector: @selector(removeMenuView)])
    {
      NSMenuView *menuView = RETAIN ([windowView removeMenuView]);

      objc_setAssociatedObject (window, &GnomeThemePrimaryBarHeightKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
      if (menuView != nil)
        {
          [windowView addMenuView: menuView];
        }
      RELEASE (menuView);
    }
  if (toolbar != nil && [toolbar respondsToSelector: @selector(_toolbarView)])
    {
      NSView *toolbarView = [toolbar _toolbarView];

      [toolbarView setFrame: [toolbarView frame]];
      GnomeThemePlaceToolbarButton (toolbarView);
    }
}

@implementation GnomeTheme (PrimaryMenu)

/* The window's menu bar: a slim bar for the ☰ when there's no toolbar, none
   when the toolbar holds it. The height is kept per window so the menu view
   is removed with the height it was added with. */
- (float) menuHeightForWindow: (NSWindow *)window
{
  NSNumber *given;

  if (GnomeThemeUsesPrimaryMenu () == NO)
    {
      return [super menuHeightForWindow: window];
    }
  given = objc_getAssociatedObject (window, &GnomeThemePrimaryBarHeightKey);
  if (given == nil)
    {
      given = [NSNumber numberWithFloat: GnomeThemePrimaryBarHeightForWindow (window)];
      objc_setAssociatedObject (window, &GnomeThemePrimaryBarHeightKey, given, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
  return [given floatValue];
}

/* As GSTheme's, with the ☰ button added to the menu view, and the stored
   height dropped between taking the old menu view out and putting the new
   one in. */
- (void) setMenu: (NSMenu *)menu
       forWindow: (NSWindow *)window
{
  id windowView = [window windowView];

  if (GnomeThemeUsesPrimaryMenu () == NO)
    {
      [super setMenu: menu forWindow: window];
      return;
    }
  if ([window menu] == menu)
    {
      return;
    }
  [window _setMenu: menu];
  [windowView removeMenuView];
  objc_setAssociatedObject (window, &GnomeThemePrimaryBarHeightKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  if (menu != nil)
    {
      NSMenuView *menuView = AUTORELEASE ([[NSMenuView alloc] initWithFrame: NSZeroRect]);
      GnomeThemePrimaryMenuButton *button;

      [menuView setMenu: menu];
      [menuView setHorizontal: YES];
      [menuView setInterfaceStyle: NSWindows95InterfaceStyle];
      [windowView addMenuView: menuView];
      [menuView sizeToFit];
      if (GnomeThemeUsesHeaderBar () == NO)
        {
          button = AUTORELEASE ([[GnomeThemePrimaryMenuButton alloc] initWithFrame: [menuView bounds]]);
          [button setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
          [menuView addSubview: button];
        }
    }
  GnomeThemeUpdatePrimaryMenuPlacement (window);
  /* The header bar shows or hides its ☰ with the window's menu. */
  if (GnomeThemeUsesHeaderBar () && [windowView respondsToSelector: @selector(updateRects)])
    {
      [windowView updateRects];
    }
}

/* The menu view holds only the ☰ button, which draws the bar; the menu's
   own titles and clicks are left out. */
- (void) _overrideNSMenuViewMethod_drawRect: (NSRect)rect
{
  typedef void (*DrawIMP)(id, SEL, NSRect);
  DrawIMP originalIMP = (DrawIMP)GnomeThemeOriginalMethod (_cmd, self, [NSMenuView class]);

  if (GnomeThemeUsesPrimaryMenu () && [(NSMenuView *)self isHorizontal])
    {
      return;
    }
  if (originalIMP != NULL)
    {
      originalIMP (self, _cmd, rect);
    }
}

- (void) _overrideNSMenuViewMethod_mouseDown: (NSEvent *)event
{
  typedef void (*MouseIMP)(id, SEL, NSEvent *);
  MouseIMP originalIMP = (MouseIMP)GnomeThemeOriginalMethod (_cmd, self, [NSMenuView class]);

  if (GnomeThemeUsesPrimaryMenu () && [(NSMenuView *)self isHorizontal]
    && [[(NSMenuView *)self window] menu] == [(NSMenuView *)self menu])
    {
      /* NSMenuView takes its subviews' clicks: pass them to the ☰. */
      NSEnumerator *enumerator = [[(NSView *)self subviews] objectEnumerator];
      NSView *subview;

      while ((subview = [enumerator nextObject]) != nil)
        {
          if ([subview isKindOfClass: [GnomeThemePrimaryMenuButton class]])
            {
              [subview mouseDown: event];
            }
        }
      return;
    }
  if (originalIMP != NULL)
    {
      originalIMP (self, _cmd, event);
    }
}

/* A toolbar in a window with the primary menu leaves room at its end for
   the ☰ button. */
- (void) _overrideGSToolbarViewMethod_setFrame: (NSRect)frame
{
  typedef void (*SetFrameIMP)(id, SEL, NSRect);
  SetFrameIMP originalIMP = (SetFrameIMP)GnomeThemeOriginalMethod (_cmd, self, NSClassFromString (@"GSToolbarView"));
  NSView *toolbarView = (NSView *)self;
  NSWindow *window = [toolbarView window];
  NSView *superview = [toolbarView superview];

  if (window != nil && superview != nil && GnomeThemeUsesPrimaryMenu () && [window menu] != nil
    && GnomeThemeUsesHeaderBar () == NO && GnomeThemeWindowShowsToolbar (window))
    {
      frame.size.width = MIN (NSWidth (frame),
                              NSMaxX ([superview bounds]) - NSMinX (frame) - GnomeThemePrimaryToolbarButtonWidth ());
    }
  if (originalIMP != NULL)
    {
      originalIMP (self, _cmd, frame);
    }
  GnomeThemePlaceToolbarButton (toolbarView);
}

- (void) _overrideGSToolbarViewMethod_viewDidMoveToWindow
{
  typedef void (*MovedIMP)(id, SEL);
  MovedIMP originalIMP = (MovedIMP)GnomeThemeOriginalMethod (_cmd, self, NSClassFromString (@"GSToolbarView"));

  if (originalIMP != NULL)
    {
      originalIMP (self, _cmd);
    }
  if ([(NSView *)self window] == nil)
    {
      GnomeThemePlaceToolbarButton ((NSView *)self);
    }
}

/* A toolbar set or shown after the menu bar, or hidden: move the ☰. */
- (void) _overrideNSWindowMethod_setToolbar: (NSToolbar *)toolbar
{
  typedef void (*SetToolbarIMP)(id, SEL, NSToolbar *);
  SetToolbarIMP originalIMP = (SetToolbarIMP)GnomeThemeOriginalMethod (_cmd, self, [NSWindow class]);
  NSToolbar *old = RETAIN ([(NSWindow *)self toolbar]);

  if (originalIMP != NULL)
    {
      originalIMP (self, _cmd, toolbar);
    }
  if (GnomeThemeUsesPrimaryMenu ())
    {
      if (old != nil && old != toolbar && [old respondsToSelector: @selector(_toolbarView)])
        {
          GnomeThemePlaceToolbarButton ([old _toolbarView]);
        }
      GnomeThemeUpdatePrimaryMenuPlacement ((NSWindow *)self);
    }
  RELEASE (old);
}

- (void) _overrideNSToolbarMethod_setVisible: (BOOL)flag
{
  typedef void (*SetVisibleIMP)(id, SEL, BOOL);
  SetVisibleIMP originalIMP = (SetVisibleIMP)GnomeThemeOriginalMethod (_cmd, self, [NSToolbar class]);
  NSToolbar *toolbar = (NSToolbar *)self;
  NSView *toolbarView = [toolbar respondsToSelector: @selector(_toolbarView)] ? [toolbar _toolbarView] : nil;
  NSWindow *window = [toolbarView window];

  if (originalIMP != NULL)
    {
      originalIMP (self, _cmd, flag);
    }
  if (GnomeThemeUsesPrimaryMenu ())
    {
      if (window == nil)
        {
          window = [toolbarView window];
        }
      GnomeThemePlaceToolbarButton (toolbarView);
      if (window != nil)
        {
          GnomeThemeUpdatePrimaryMenuPlacement (window);
        }
    }
}

@end
