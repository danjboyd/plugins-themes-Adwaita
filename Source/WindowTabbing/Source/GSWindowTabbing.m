/* GSWindowTabbing.m: NSWindow's tabbing API, installed at run time.

   Copyright (C) 2026 Daniel Boyd

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/>.
*/

/* dladdr() */
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include <dlfcn.h>

#import "GSWindowTabbingPrivate.h"
#import "GSWindowTabBarView.h"
#import <GNUstepGUI/GSWindowDecorationView.h>
#import <objc/runtime.h>

#ifndef GS_HAS_WINDOW_TABBING

@interface NSWindow (GSWindowTabbingLibsGUI)
- (NSView *) _windowView;
@end

/* What a window has for tabbing, kept beside it: NSWindow has no room
   for it. */
@interface GSWindowTabbingState : NSObject
{
@public
  NSWindowTabbingMode mode;
  NSString *identifier;
  NSWindowTab *tab;
  NSWindowTabGroup *group;
  GSWindowTabBarView *barView;
  BOOL shown;
}
@end

@implementation GSWindowTabbingState
/* The copy of this code the runtime kept the classes of (see
   GSTabClassesAreOurs()) answers these. */
+ (BOOL) gsInstallTabbing
{
  return GSWindowTabbingInstall ();
}

+ (NSView *) gsTabBarViewForWindow: (NSWindow *)window
{
  return GSWindowTabBarViewForWindow (window);
}

- (void) dealloc
{
  RELEASE (identifier);
  RELEASE (tab);
  RELEASE (group);
  [barView removeFromSuperview];
  RELEASE (barView);
  [super dealloc];
}
@end

static NSMapTable *states = NULL;
static BOOL installed = NO;

/* When an app and a theme both build this code in, the runtime keeps one
   copy of each class (libobjc2 warns "Loading two versions of ..."), and
   each copy's functions keep their own state. Only the copy whose classes
   were kept can work, so the other one hands its public functions to it. */
static BOOL
GSTabClassesAreOurs (void)
{
  static int ours = -1;

  if (ours < 0)
    {
      Method method = class_getClassMethod ([GSWindowTabbingState class],
                                            @selector(gsInstallTabbing));
      Dl_info classes, functions;

      ours = 1;
      if (method != NULL
          && dladdr ((void *)method_getImplementation (method), &classes) != 0
          && dladdr ((void *)GSTabClassesAreOurs, &functions) != 0
          && classes.dli_fbase != functions.dli_fbase)
        {
          ours = 0;
        }
    }
  return ours == 1;
}

static BOOL allowsAutomaticTabbing = YES;
/* Nonzero while the group orders its own windows in and out. */
static int internalOrdering = 0;
/* The window whose "+" button is asking for a new tab: the next window
   ordered in for the first time joins its group. */
static NSWindow *newTabWindow = nil;

static GSWindowTabbingState *
GSTabState (NSWindow *window, BOOL create)
{
  GSWindowTabbingState *state = NSMapGet (states, window);

  if (state == nil && create)
    {
      state = [GSWindowTabbingState new];
      state->mode = NSWindowTabbingModeAutomatic;
      NSMapInsert (states, window, state);
      RELEASE (state);
    }
  return state;
}

/* Windows that can be tabs: titled windows that aren't panels. */
static BOOL
GSWindowCanBeTabbed (NSWindow *window)
{
  return [window isKindOfClass: [NSPanel class]] == NO
    && ([window styleMask] & NSTitledWindowMask) != 0
    && [window tabbingMode] != NSWindowTabbingModeDisallowed;
}

/* The height a window gives up for its tab bar. */
static CGFloat
GSTabBarReservedHeight (NSWindow *window)
{
  GSWindowTabbingState *state;
  GSTheme *theme;

  if (states == NULL || window == nil)
    {
      return 0.0;
    }
  state = GSTabState (window, NO);
  if (state == nil || state->group == nil || [state->group isTabBarVisible] == NO)
    {
      return 0.0;
    }
  theme = [GSTheme theme];
  if ([theme windowTabBarPlacementForWindow: window] != GSWindowTabBarAboveContent)
    {
      return 0.0;
    }
  return [theme windowTabBarHeightForWindow: window];
}

NSView *
GSWindowTabBarViewForWindow (NSWindow *window)
{
  GSWindowTabbingState *state;

  if (GSTabClassesAreOurs () == NO)
    {
      return [GSWindowTabbingState gsTabBarViewForWindow: window];
    }
  state = (states != NULL) ? GSTabState (window, NO) : nil;

  if (state == nil || state->group == nil || [state->group isTabBarVisible] == NO)
    {
      return nil;
    }
  return state->barView;
}

/* Puts the bar in the window or takes it out, and lays the window out
   again: the window keeps its frame, and the content gives up or takes
   back the bar's row. */
static void
GSTabUpdateBar (NSWindow *window)
{
  GSWindowTabbingState *state = GSTabState (window, NO);
  NSView *decoration = [window _windowView];
  BOOL visible = (state != nil && state->group != nil
                  && [state->group isTabBarVisible]);

  if (visible)
    {
      if (state->barView == nil)
        {
          state->barView = [[GSWindowTabBarView alloc] initWithWindow: window];
        }
      if ([state->barView superview] != decoration)
        {
          [decoration addSubview: state->barView];
        }
      [state->barView tabsDidChange];
    }
  else if (state != nil && state->barView != nil)
    {
      [state->barView removeFromSuperview];
    }
  if ([decoration respondsToSelector: @selector(layout)])
    {
      [(GSWindowDecorationView *)decoration layout];
    }
  [decoration setNeedsDisplay: YES];
  [[NSNotificationCenter defaultCenter]
    postNotificationName: @"GSWindowTabBarDidChangeNotification"
                  object: window];
}


/* Replaces a method of cls with imp, keeping the old one in *original.
   An inherited method is overridden in cls rather than changed in its
   superclass. */
static void
GSTabHook (Class cls, SEL selector, IMP imp, IMP *original)
{
  Method method = class_getInstanceMethod (cls, selector);

  if (method == NULL)
    {
      *original = NULL;
      return;
    }
  *original = method_getImplementation (method);
  if (class_addMethod (cls, selector, imp, method_getTypeEncoding (method)) == NO)
    {
      method_setImplementation (method, imp);
    }
}

/* Adds donor's methods to target where target has none of that name. */
static void
GSTabAddMethods (Class donor, Class target)
{
  unsigned int count = 0;
  unsigned int i;
  Method *methods = class_copyMethodList (donor, &count);

  for (i = 0; i < count; i++)
    {
      SEL selector = method_getName (methods[i]);

      if (class_getInstanceMethod (target, selector) == NULL)
        {
          class_addMethod (target, selector, method_getImplementation (methods[i]),
                           method_getTypeEncoding (methods[i]));
        }
    }
  free (methods);
}


/* The NSWindow methods, added to NSWindow by GSTabAddMethods: self is
   the window. */
@interface GSWindowTabbingWindowMethods : NSObject
@end

@interface GSWindowTabbingWindowClassMethods : NSObject
@end

@implementation GSWindowTabbingWindowClassMethods

- (BOOL) allowsAutomaticWindowTabbing
{
  return allowsAutomaticTabbing;
}

- (void) setAllowsAutomaticWindowTabbing: (BOOL)flag
{
  allowsAutomaticTabbing = flag;
}

/* AppleWindowTabbingMode, as on macOS: always, manual or fullscreen
   (the default; GNUstep has no full-screen spaces, so it means manual). */
- (NSWindowUserTabbingPreference) userTabbingPreference
{
  NSString *mode = [[NSUserDefaults standardUserDefaults]
                     stringForKey: @"AppleWindowTabbingMode"];

  if ([mode isEqualToString: @"always"])
    {
      return NSWindowUserTabbingPreferenceAlways;
    }
  if ([mode isEqualToString: @"manual"])
    {
      return NSWindowUserTabbingPreferenceManual;
    }
  return NSWindowUserTabbingPreferenceInFullScreen;
}

@end

#define WINDOW ((NSWindow *)self)

@implementation GSWindowTabbingWindowMethods

- (NSWindowTabbingMode) tabbingMode
{
  GSWindowTabbingState *state = GSTabState (WINDOW, NO);

  return (state != nil) ? state->mode : NSWindowTabbingModeAutomatic;
}

- (void) setTabbingMode: (NSWindowTabbingMode)mode
{
  GSTabState (WINDOW, YES)->mode = mode;
}

/* By default the window's class: windows of one kind tab together. */
- (NSWindowTabbingIdentifier) tabbingIdentifier
{
  GSWindowTabbingState *state = GSTabState (WINDOW, NO);

  if (state != nil && state->identifier != nil)
    {
      return state->identifier;
    }
  return NSStringFromClass ([self class]);
}

- (void) setTabbingIdentifier: (NSWindowTabbingIdentifier)identifier
{
  ASSIGNCOPY (GSTabState (WINDOW, YES)->identifier, identifier);
}

- (NSWindowTabGroup *) tabGroup
{
  GSWindowTabbingState *state = GSTabState (WINDOW, YES);

  if (state->group == nil)
    {
      NSWindowTabGroup *group = [[NSWindowTabGroup alloc]
                                  initWithIdentifier: [WINDOW tabbingIdentifier]];

      [group addWindow: WINDOW];
      RELEASE (group);
    }
  return state->group;
}

- (NSArray *) tabbedWindows
{
  GSWindowTabbingState *state = GSTabState (WINDOW, NO);

  if (state == nil || state->group == nil || [[state->group windows] count] < 2)
    {
      return nil;
    }
  return [state->group windows];
}

- (NSWindowTab *) tab
{
  GSWindowTabbingState *state = GSTabState (WINDOW, YES);

  if (state->tab == nil)
    {
      state->tab = [[NSWindowTab alloc] initWithWindow: WINDOW];
    }
  return state->tab;
}

/* The window joins the receiver's group beside it, and becomes its
   selected tab. */
- (void) addTabbedWindow: (NSWindow *)window ordered: (NSWindowOrderingMode)ordered
{
  NSWindowTabGroup *group;
  NSUInteger index;

  if (window == nil || window == WINDOW)
    {
      return;
    }
  group = [WINDOW tabGroup];
  index = [[group windows] indexOfObjectIdenticalTo: WINDOW];
  if (ordered != NSWindowBelow)
    {
      index++;
    }
  GSTabState (window, YES)->shown = YES;
  [group insertWindow: window atIndex: index];
}

- (IBAction) selectNextTab: (id)sender
{
  [[WINDOW tabGroup] gsSelectNextTab: YES];
}

- (IBAction) selectPreviousTab: (id)sender
{
  [[WINDOW tabGroup] gsSelectNextTab: NO];
}

/* The tab leaves its group for a window of its own, a little below and
   to the right of the group. */
- (IBAction) moveTabToNewWindow: (id)sender
{
  NSWindowTabGroup *group = [WINDOW tabGroup];
  NSRect frame;

  if ([[group windows] count] < 2)
    {
      return;
    }
  frame = [WINDOW frame];
  [group removeWindow: WINDOW];
  frame.origin.x += 30.0;
  frame.origin.y -= 30.0;
  internalOrdering++;
  [WINDOW setFrame: frame display: NO];
  [WINDOW makeKeyAndOrderFront: nil];
  internalOrdering--;
}

/* Every window that can tab with this one joins its group; this one
   stays selected. */
- (IBAction) mergeAllWindows: (id)sender
{
  NSArray *windows = [NSApp windows];
  NSWindowTabGroup *group = [WINDOW tabGroup];
  NSString *identifier = [WINDOW tabbingIdentifier];
  NSUInteger i;

  for (i = 0; i < [windows count]; i++)
    {
      NSWindow *window = [windows objectAtIndex: i];
      GSWindowTabbingState *state = GSTabState (window, NO);

      if (window == WINDOW || GSWindowCanBeTabbed (window) == NO
        || [[window tabbingIdentifier] isEqual: identifier] == NO
        || [[group windows] indexOfObjectIdenticalTo: window] != NSNotFound)
        {
          continue;
        }
      if ([window isVisible] || (state != nil && state->group != nil))
        {
          [group addWindow: window];
        }
    }
  [group setSelectedWindow: WINDOW];
}

- (IBAction) toggleTabBar: (id)sender
{
  [[WINDOW tabGroup] gsToggleTabBar];
}

/* GSWindowTabbable */

- (void) gsTabShowWithFrame: (NSRect)frame makeKey: (BOOL)makeKey
{
  internalOrdering++;
  [WINDOW setFrame: frame display: NO];
  if (makeKey)
    {
      [WINDOW makeKeyAndOrderFront: nil];
    }
  else
    {
      [WINDOW orderFront: nil];
    }
  internalOrdering--;
}

- (void) gsTabHide
{
  internalOrdering++;
  [WINDOW orderOut: nil];
  internalOrdering--;
}

- (void) gsTabGroupDidChange
{
  GSTabUpdateBar (WINDOW);
}

- (NSWindowTabGroup *) gsTabGroup
{
  GSWindowTabbingState *state = GSTabState (WINDOW, NO);

  return (state != nil) ? state->group : nil;
}

- (void) gsSetTabGroup: (NSWindowTabGroup *)group
{
  ASSIGN (GSTabState (WINDOW, YES)->group, group);
}

@end


/* Hooks on methods NSWindow and GSWindowDecorationView already have. */

static IMP originalOrderWindow;
static IMP originalSetTitle;
static IMP originalSetTitleWithRepresentedFilename;
static IMP originalSetDocumentEdited;
static IMP originalSendEvent;
static IMP originalPerformKeyEquivalent;
static IMP originalClose;
static IMP originalValidateUserInterfaceItem;
static IMP originalWindowDealloc;
static IMP originalDecorationLayout;
static IMP originalContentRectForFrameRect;
static IMP originalFrameRectForContentRect;

/* The window a new window ordered in for the first time joins, if any:
   the "+" button's window, or with automatic tabbing the key window. */
static NSWindow *
GSTabWindowToJoin (NSWindow *window)
{
  NSWindowTabbingMode mode;
  NSWindow *key;

  if (GSWindowCanBeTabbed (window) == NO)
    {
      return nil;
    }
  if (newTabWindow != nil && newTabWindow != window)
    {
      return newTabWindow;
    }
  mode = [window tabbingMode];
  if (mode == NSWindowTabbingModeAutomatic
    && ([NSWindow allowsAutomaticWindowTabbing] == NO
        || [NSWindow userTabbingPreference] != NSWindowUserTabbingPreferenceAlways))
    {
      return nil;
    }
  /* The key window; while the app isn't active (NSApp has none) the
     window that says it's key, the main window, or else the frontmost
     window this one can tab with. */
  key = [NSApp keyWindow];
  if (key == nil)
    {
      NSArray *ordered = [NSApp orderedWindows];
      NSUInteger i;

      for (i = 0; i < [ordered count] && key == nil; i++)
        {
          if ([[ordered objectAtIndex: i] isKeyWindow])
            {
              key = [ordered objectAtIndex: i];
            }
        }
      if (key == nil)
        {
          key = [NSApp mainWindow];
        }
      for (i = 0; i < [ordered count] && key == nil; i++)
        {
          NSWindow *candidate = [ordered objectAtIndex: i];

          if (candidate != window && [candidate isVisible]
            && GSWindowCanBeTabbed (candidate)
            && [[candidate tabbingIdentifier] isEqual: [window tabbingIdentifier]])
            {
              key = candidate;
            }
        }
    }
  if (key == nil || key == window || [key isVisible] == NO
    || GSWindowCanBeTabbed (key) == NO
    || [[key tabbingIdentifier] isEqual: [window tabbingIdentifier]] == NO)
    {
      return nil;
    }
  return key;
}

static void
GSTabOrderWindow (id self, SEL _cmd, NSWindowOrderingMode place, NSInteger other)
{
  if (internalOrdering == 0 && place != NSWindowOut)
    {
      GSWindowTabbingState *state = GSTabState (WINDOW, NO);
      NSWindowTabGroup *group = (state != nil) ? state->group : nil;

      /* A hidden tab ordered in (the Windows menu, makeKeyAndOrderFront:)
         becomes its group's selected tab. */
      if (group != nil && [[group windows] count] > 1
        && [group selectedWindow] != WINDOW)
        {
          [group setSelectedWindow: WINDOW];
          return;
        }
      if ((state == nil || state->shown == NO) && [WINDOW isVisible] == NO)
        {
          NSWindow *join = GSTabWindowToJoin (WINDOW);

          GSTabState (WINDOW, YES)->shown = YES;
          if (join != nil)
            {
              [join addTabbedWindow: WINDOW ordered: NSWindowAbove];
              return;
            }
        }
    }
  if (place != NSWindowOut)
    {
      GSTabState (WINDOW, YES)->shown = YES;
    }
  ((void (*)(id, SEL, NSWindowOrderingMode, NSInteger))originalOrderWindow) (self, _cmd, place, other);
}

static void
GSTabRedrawBar (NSWindow *window)
{
  GSWindowTabbingState *state = GSTabState (window, NO);
  NSArray *windows;
  NSUInteger i;

  if (state == nil || state->group == nil)
    {
      return;
    }
  /* The bar shown is the selected window's; it draws every tab. */
  windows = [state->group windows];
  for (i = 0; i < [windows count]; i++)
    {
      GSWindowTabbingState *other = GSTabState ([windows objectAtIndex: i], NO);

      if (other != nil && other->barView != nil)
        {
          [other->barView tabsDidChange];
        }
    }
}

static void
GSTabSetTitle (id self, SEL _cmd, NSString *title)
{
  ((void (*)(id, SEL, NSString *))originalSetTitle) (self, _cmd, title);
  GSTabRedrawBar (WINDOW);
}

static void
GSTabSetTitleWithRepresentedFilename (id self, SEL _cmd, NSString *filename)
{
  ((void (*)(id, SEL, NSString *))originalSetTitleWithRepresentedFilename) (self, _cmd, filename);
  GSTabRedrawBar (WINDOW);
}

static void
GSTabSetDocumentEdited (id self, SEL _cmd, BOOL flag)
{
  ((void (*)(id, SEL, BOOL))originalSetDocumentEdited) (self, _cmd, flag);
  GSTabRedrawBar (WINDOW);
}

/* Ctrl+Tab and Ctrl+Page Down select the next tab, Ctrl+Shift+Tab and
   Ctrl+Page Up the previous one, as in GNOME's apps, while the window is
   in a group with other tabs. YES if the event was one of them. */
static BOOL
GSTabHandleShortcut (NSWindow *window, NSEvent *event)
{
  NSUInteger flags;
  NSString *characters;
  unichar c;
  BOOL shift;

  if ([event type] != NSKeyDown || [[window tabbedWindows] count] < 2)
    {
      return NO;
    }
  /* The Ctrl key, whichever modifier it arrives as: GNUstep's default
     key mapping (GSFirstCommandKey) makes the physical Ctrl key
     NSCommandKeyMask, which is why apps' Ctrl+N shortcuts are Command
     key equivalents; with Ctrl mapped to Control it is NSControlKeyMask.
     Alt with it is something else. */
  flags = [event modifierFlags];
  if ((flags & (NSControlKeyMask | NSCommandKeyMask)) == 0
    || (flags & NSAlternateKeyMask) != 0)
    {
      return NO;
    }
  characters = [event charactersIgnoringModifiers];
  c = ([characters length] > 0) ? [characters characterAtIndex: 0] : 0;
  shift = (flags & NSShiftKeyMask) != 0;
  if ((c == '\t' && shift == NO) || c == NSPageDownFunctionKey)
    {
      [window selectNextTab: nil];
      return YES;
    }
  if ((c == '\t' && shift) || c == 0x19 || c == NSPageUpFunctionKey)
    {
      [window selectPreviousTab: nil];
      return YES;
    }
  return NO;
}

/* NSApp offers a key-down to the key window's -performKeyEquivalent:
   before the window sends it to its first responder, so the tab
   shortcuts are taken here, ahead of a text view (which would insert a
   tab or scroll) and of the window's own Ctrl+Tab key view loop. */
static BOOL
GSTabPerformKeyEquivalent (id self, SEL _cmd, NSEvent *event)
{
  if (GSTabHandleShortcut (WINDOW, event))
    {
      return YES;
    }
  return ((BOOL (*)(id, SEL, NSEvent *))originalPerformKeyEquivalent) (self, _cmd, event);
}

/* And here, for a key-down sent to the window directly. */
static void
GSTabSendEvent (id self, SEL _cmd, NSEvent *event)
{
  if (GSTabHandleShortcut (WINDOW, event))
    {
      return;
    }
  ((void (*)(id, SEL, NSEvent *))originalSendEvent) (self, _cmd, event);
}

/* Closing the selected tab shows its neighbour first, so the app never
   sees a moment with no window on screen: NSApplication decides at
   NSWindowWillCloseNotification, from the windows on screen, whether the
   last window closed (and so whether to terminate, for apps whose
   -applicationShouldTerminateAfterLastWindowClosed: says YES). The
   window leaves its group before it closes. */
static void
GSTabClose (id self, SEL _cmd)
{
  GSWindowTabbingState *state = GSTabState (WINDOW, NO);
  NSWindowTabGroup *group = (state != nil) ? state->group : nil;

  if (group != nil && [[group windows] count] > 1)
    {
      RETAIN (group);
      [group removeWindow: WINDOW];
      RELEASE (group);
    }
  ((void (*)(id, SEL))originalClose) (self, _cmd);
}

static BOOL
GSTabValidateUserInterfaceItem (id self, SEL _cmd, id item)
{
  SEL action = [item action];
  NSUInteger count = [[WINDOW tabbedWindows] count];

  if (sel_isEqual (action, @selector(selectNextTab:))
    || sel_isEqual (action, @selector(selectPreviousTab:))
    || sel_isEqual (action, @selector(moveTabToNewWindow:)))
    {
      return count > 1;
    }
  if (sel_isEqual (action, @selector(toggleTabBar:)))
    {
      if (GSWindowCanBeTabbed (WINDOW) == NO)
        {
          return NO;
        }
      if ([item isKindOfClass: [NSMenuItem class]])
        {
          BOOL visible = [[WINDOW tabGroup] isTabBarVisible];

          [(NSMenuItem *)item setTitle: visible ? @"Hide Tab Bar" : @"Show Tab Bar"];
        }
      return YES;
    }
  if (sel_isEqual (action, @selector(mergeAllWindows:)))
    {
      NSArray *windows = [NSApp windows];
      NSUInteger i;

      if (GSWindowCanBeTabbed (WINDOW) == NO)
        {
          return NO;
        }
      for (i = 0; i < [windows count]; i++)
        {
          NSWindow *window = [windows objectAtIndex: i];

          if (window != WINDOW && GSWindowCanBeTabbed (window)
            && [[window tabbingIdentifier] isEqual: [WINDOW tabbingIdentifier]]
            && [[[WINDOW tabGroup] windows] indexOfObjectIdenticalTo: window] == NSNotFound
            && [window isVisible])
            {
              return YES;
            }
        }
      return NO;
    }
  return ((BOOL (*)(id, SEL, id))originalValidateUserInterfaceItem) (self, _cmd, item);
}

static void
GSTabWindowDealloc (id self, SEL _cmd)
{
  if (newTabWindow == WINDOW)
    {
      newTabWindow = nil;
    }
  NSMapRemove (states, self);
  ((void (*)(id, SEL))originalWindowDealloc) (self, _cmd);
}

/* After the decoration has laid out the title bar, menu bar and toolbar,
   the tab bar takes the top of what is left. */
static void
GSTabDecorationLayout (id self, SEL _cmd)
{
  NSWindow *window = [(NSView *)self window];
  CGFloat height;
  NSView *content;
  GSWindowTabbingState *state;

  ((void (*)(id, SEL))originalDecorationLayout) (self, _cmd);
  height = GSTabBarReservedHeight (window);
  state = (window != nil) ? GSTabState (window, NO) : nil;
  content = [window contentView];
  if (height > 0.0 && state != nil && state->barView != nil
    && [content superview] == self)
    {
      NSRect frame = [content frame];

      [state->barView setFrame: NSMakeRect (NSMinX (frame), NSMaxY (frame) - height,
                                            NSWidth (frame), height)];
      frame.size.height -= height;
      [content setFrame: frame];
    }
}

static NSRect
GSTabContentRectForFrameRect (id self, SEL _cmd, NSRect frame, NSUInteger style)
{
  NSRect content = ((NSRect (*)(id, SEL, NSRect, NSUInteger))originalContentRectForFrameRect)
    (self, _cmd, frame, style);

  content.size.height -= GSTabBarReservedHeight ([(NSView *)self window]);
  return content;
}

static NSRect
GSTabFrameRectForContentRect (id self, SEL _cmd, NSRect content, NSUInteger style)
{
  CGFloat height = GSTabBarReservedHeight ([(NSView *)self window]);

  content.size.height += height;
  return ((NSRect (*)(id, SEL, NSRect, NSUInteger))originalFrameRectForContentRect)
    (self, _cmd, content, style);
}


/* A closing window leaves its group; its neighbour takes its place. */
@interface GSWindowTabbingObserver : NSObject
@end

@implementation GSWindowTabbingObserver
- (void) windowWillClose: (NSNotification *)notification
{
  NSWindow *window = [notification object];
  GSWindowTabbingState *state = GSTabState (window, NO);

  if (state != nil && state->group != nil)
    {
      NSWindowTabGroup *group = RETAIN (state->group);

      [group gsWindowWillLeave: window];
      [(id)window gsSetTabGroup: nil];
      RELEASE (group);
    }
}
@end

void
GSWindowTabbingSendNewWindowForTab (NSWindow *window)
{
  newTabWindow = window;
  [NSApp sendAction: @selector(newWindowForTab:) to: nil from: window];
  newTabWindow = nil;
}

BOOL
GSWindowTabbingCanCreateNewTab (NSWindow *window)
{
  return [NSApp targetForAction: @selector(newWindowForTab:) to: nil from: window] != nil;
}

#endif /* GS_HAS_WINDOW_TABBING */

BOOL
GSWindowTabbingInstall (void)
{
#ifdef GS_HAS_WINDOW_TABBING
  return NO;
#else
  static GSWindowTabbingObserver *observer = nil;
  Class window = [NSWindow class];
  Class decoration = [GSWindowDecorationView class];

  if (installed)
    {
      return YES;
    }
  if (GSTabClassesAreOurs () == NO)
    {
      return [GSWindowTabbingState gsInstallTabbing];
    }
  if ([NSWindow instancesRespondToSelector: @selector(addTabbedWindow:ordered:)])
    {
      /* Native tabbing (or another copy of this code): nothing to do. */
      return NO;
    }
  installed = YES;
  states = NSCreateMapTable (NSNonOwnedPointerMapKeyCallBacks,
                             NSObjectMapValueCallBacks, 64);

  GSTabAddMethods ([GSWindowTabbingWindowMethods class], window);
  /* The donor's instance methods become NSWindow's class methods. */
  GSTabAddMethods ([GSWindowTabbingWindowClassMethods class], object_getClass (window));
  GSWindowTabbingInstallThemeDefaults ();

  GSTabHook (window, @selector(orderWindow:relativeTo:),
             (IMP)GSTabOrderWindow, &originalOrderWindow);
  GSTabHook (window, @selector(setTitle:), (IMP)GSTabSetTitle, &originalSetTitle);
  GSTabHook (window, @selector(setTitleWithRepresentedFilename:),
             (IMP)GSTabSetTitleWithRepresentedFilename,
             &originalSetTitleWithRepresentedFilename);
  GSTabHook (window, @selector(setDocumentEdited:),
             (IMP)GSTabSetDocumentEdited, &originalSetDocumentEdited);
  GSTabHook (window, @selector(sendEvent:), (IMP)GSTabSendEvent, &originalSendEvent);
  GSTabHook (window, @selector(performKeyEquivalent:),
             (IMP)GSTabPerformKeyEquivalent, &originalPerformKeyEquivalent);
  GSTabHook (window, @selector(close), (IMP)GSTabClose, &originalClose);
  GSTabHook (window, @selector(validateUserInterfaceItem:),
             (IMP)GSTabValidateUserInterfaceItem, &originalValidateUserInterfaceItem);
  GSTabHook (window, @selector(dealloc), (IMP)GSTabWindowDealloc, &originalWindowDealloc);
  GSTabHook (decoration, @selector(layout), (IMP)GSTabDecorationLayout,
             &originalDecorationLayout);
  GSTabHook (decoration, @selector(contentRectForFrameRect:styleMask:),
             (IMP)GSTabContentRectForFrameRect, &originalContentRectForFrameRect);
  GSTabHook (decoration, @selector(frameRectForContentRect:styleMask:),
             (IMP)GSTabFrameRectForContentRect, &originalFrameRectForContentRect);

  observer = [GSWindowTabbingObserver new];
  [[NSNotificationCenter defaultCenter] addObserver: observer
                                           selector: @selector(windowWillClose:)
                                               name: NSWindowWillCloseNotification
                                             object: nil];
  return YES;
#endif
}
