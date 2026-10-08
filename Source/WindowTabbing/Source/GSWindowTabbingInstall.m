/** <title>GSWindowTabbingInstall</title>

   <abstract>Installs window tabbing into NSWindow, GSWindowDecorationView
   and GSTheme at run time.</abstract>

   Copyright (C) 2026 Daniel Boyd

   Author: Daniel Boyd <danieljboyd@icloud.com>
   Date: 2026

   This file is part of the GNUstep GUI Library.

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
   If not, see <http://www.gnu.org/licenses/> or write to the
   Free Software Foundation, 51 Franklin Street, Fifth Floor,
   Boston, MA 02110-1301, USA.
*/

/* This file is the part that would not go upstream.  The tabbing itself
   is written as NSWindow's, GSWindowDecorationView's and GSTheme's own
   methods (GSWindowTabbingWindow.m, GSWindowTabbingDecorationView.m,
   GSWindowTabbingTheme.m).  Here they are copied into those classes, a
   window's tabbing state is kept beside it, and the methods those
   classes already have are wrapped so they call the tabbing's: upstream
   each wrapper is one call inside the method itself, and this file is
   deleted. */

/* dladdr() */
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include <dlfcn.h>
#include <stdlib.h>

#import "GSWindowTabbingPrivate.h"
#import "GSWindowTabBarView.h"
#import <objc/runtime.h>

#ifndef GS_HAS_WINDOW_TABBING

/* The tabbing state of each window, keyed by the window (not retained). */
static NSMapTable *states = NULL;
static BOOL installed = NO;

@implementation GSWindowTabbingState

/* When an app and its theme both build this code in, the runtime keeps
   one copy of each class (libobjc2 warns "Loading two versions of ..."),
   while each copy's C functions keep their own static state.  Only the
   copy whose classes were kept can work, so the other copy's public
   functions call these, which run in the kept copy. */
+ (BOOL) _installTabbing
{
  return GSWindowTabbingInstall();
}

+ (NSView *) _tabBarViewForWindow: (NSWindow *)window
{
  return GSWindowTabBarViewForWindow(window);
}

- (void) dealloc
{
  RELEASE(identifier);
  RELEASE(tab);
  RELEASE(group);
  [barView removeFromSuperview];
  RELEASE(barView);
  [super dealloc];
}

@end

GSWindowTabbingState *
GSWindowTabbingStateForWindow(NSWindow *window, BOOL create)
{
  GSWindowTabbingState *state;

  if (states == NULL || window == nil)
    {
      return nil;
    }
  state = NSMapGet(states, window);
  if (state == nil && create)
    {
      state = [GSWindowTabbingState new];
      state->mode = NSWindowTabbingModeAutomatic;
      NSMapInsert(states, window, state);
      RELEASE(state);
    }
  return state;
}

void
GSWindowTabbingForgetWindow(NSWindow *window)
{
  if (states != NULL)
    {
      NSMapRemove(states, window);
    }
}

/* Is this copy of the code the one whose classes the runtime kept (see
   +[GSWindowTabbingState _installTabbing])?  The kept class's method
   lives in the same loaded object as this function only then. */
static BOOL
GSWindowTabbingClassesAreOurs(void)
{
  static int ours = -1;

  if (ours < 0)
    {
      Method method;
      Dl_info classes;
      Dl_info functions;

      method = class_getClassMethod([GSWindowTabbingState class],
                                    @selector(_installTabbing));
      ours = 1;
      if (method != NULL
        && dladdr((void *)method_getImplementation(method), &classes) != 0
        && dladdr((void *)GSWindowTabbingClassesAreOurs, &functions) != 0
        && classes.dli_fbase != functions.dli_fbase)
        {
          ours = 0;
        }
    }
  return ours == 1;
}


/* Copying and wrapping methods. */

/* Adds donor's methods to target where target has none of that name:
   donor is a subclass of target written only to hold them. */
static void
GSWindowTabbingAddMissingMethods(Class donor, Class target)
{
  unsigned int count = 0;
  unsigned int i;
  Method *methods = class_copyMethodList(donor, &count);

  for (i = 0; i < count; i++)
    {
      SEL selector = method_getName(methods[i]);

      if (class_getInstanceMethod(target, selector) == NULL)
        {
          class_addMethod(target, selector,
                          method_getImplementation(methods[i]),
                          method_getTypeEncoding(methods[i]));
        }
    }
  free(methods);
}

/* Replaces cls's method selector with imp, keeping the old one in
   *original.  An inherited method is overridden in cls rather than
   changed in its superclass. */
static void
GSWindowTabbingWrapMethod(Class cls, SEL selector, IMP imp, IMP *original)
{
  Method method = class_getInstanceMethod(cls, selector);

  if (method == NULL)
    {
      *original = NULL;
      return;
    }
  *original = method_getImplementation(method);
  if (class_addMethod(cls, selector, imp,
                      method_getTypeEncoding(method)) == NO)
    {
      method_setImplementation(method, imp);
    }
}


/* The wrappers.  Each calls the tabbing's method, then the original. */

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

/* Upstream: -[NSWindow orderWindow:relativeTo:] begins
   if ([self _tabbingOrderWindow: place]) return; */
static void
GSTabbingOrderWindow(NSWindow *self, SEL _cmd,
                     NSWindowOrderingMode place, NSInteger other)
{
  if ([self _tabbingOrderWindow: place])
    {
      return;
    }
  ((void (*)(id, SEL, NSWindowOrderingMode, NSInteger))originalOrderWindow)
    (self, _cmd, place, other);
}

/* Upstream: -setTitle:, -setTitleWithRepresentedFilename: and
   -setDocumentEdited: end with [self _tabbingTitleDidChange]; */
static void
GSTabbingSetTitle(NSWindow *self, SEL _cmd, NSString *title)
{
  ((void (*)(id, SEL, NSString *))originalSetTitle)(self, _cmd, title);
  [self _tabbingTitleDidChange];
}

static void
GSTabbingSetTitleWithRepresentedFilename(NSWindow *self, SEL _cmd,
                                         NSString *filename)
{
  ((void (*)(id, SEL, NSString *))originalSetTitleWithRepresentedFilename)
    (self, _cmd, filename);
  [self _tabbingTitleDidChange];
}

static void
GSTabbingSetDocumentEdited(NSWindow *self, SEL _cmd, BOOL flag)
{
  ((void (*)(id, SEL, BOOL))originalSetDocumentEdited)(self, _cmd, flag);
  [self _tabbingTitleDidChange];
}

/* Upstream: -performKeyEquivalent: and -sendEvent: begin
   if ([self _tabbingHandleKeyEvent: event]) return YES; (return; in
   -sendEvent:).  NSApp offers a key-down to the key window's
   -performKeyEquivalent: before the window sends it to its first
   responder, so the tab shortcuts come ahead of a text view; -sendEvent:
   catches a key-down sent to the window directly. */
static BOOL
GSTabbingPerformKeyEquivalent(NSWindow *self, SEL _cmd, NSEvent *event)
{
  if ([self _tabbingHandleKeyEvent: event])
    {
      return YES;
    }
  return ((BOOL (*)(id, SEL, NSEvent *))originalPerformKeyEquivalent)
    (self, _cmd, event);
}

static void
GSTabbingSendEvent(NSWindow *self, SEL _cmd, NSEvent *event)
{
  if ([self _tabbingHandleKeyEvent: event])
    {
      return;
    }
  ((void (*)(id, SEL, NSEvent *))originalSendEvent)(self, _cmd, event);
}

/* Upstream: -close begins [self _tabbingWillClose]; */
static void
GSTabbingClose(NSWindow *self, SEL _cmd)
{
  [self _tabbingWillClose];
  ((void (*)(id, SEL))originalClose)(self, _cmd);
}

/* Upstream: -validateUserInterfaceItem: begins
   if ([self _tabbingValidateUserInterfaceItem: item valid: &valid])
     return valid; */
static BOOL
GSTabbingValidateUserInterfaceItem(NSWindow *self, SEL _cmd, id item)
{
  BOOL valid;

  if ([self _tabbingValidateUserInterfaceItem: item valid: &valid])
    {
      return valid;
    }
  return ((BOOL (*)(id, SEL, id))originalValidateUserInterfaceItem)
    (self, _cmd, item);
}

/* Upstream: -dealloc releases the tabbing instance variables. */
static void
GSTabbingWindowDealloc(NSWindow *self, SEL _cmd)
{
  [self _tabbingDealloc];
  ((void (*)(id, SEL))originalWindowDealloc)(self, _cmd);
}

/* Upstream: -[GSWindowDecorationView layout] ends
   [self _layoutTabBar]; */
static void
GSTabbingDecorationLayout(GSWindowDecorationView *self, SEL _cmd)
{
  ((void (*)(id, SEL))originalDecorationLayout)(self, _cmd);
  [self _layoutTabBar];
}

/* Upstream: GSWindowDecorationView's -contentRectForFrameRect:styleMask:
   leaves out the tab bar's row, and -frameRectForContentRect:styleMask:
   adds it, as they do for an in-window menu bar. */
static NSRect
GSTabbingContentRectForFrameRect(GSWindowDecorationView *self, SEL _cmd,
                                 NSRect frame, NSUInteger style)
{
  NSRect content;

  content = ((NSRect (*)(id, SEL, NSRect, NSUInteger))
             originalContentRectForFrameRect)(self, _cmd, frame, style);
  content.size.height -= [[self window] _tabBarReservedHeight];
  return content;
}

static NSRect
GSTabbingFrameRectForContentRect(GSWindowDecorationView *self, SEL _cmd,
                                 NSRect content, NSUInteger style)
{
  content.size.height += [[self window] _tabBarReservedHeight];
  return ((NSRect (*)(id, SEL, NSRect, NSUInteger))
          originalFrameRectForContentRect)(self, _cmd, content, style);
}

/* Wraps the NSWindow and GSWindowDecorationView methods tabbing takes
   part in. */
static void
GSWindowTabbingWrapMethods(void)
{
  Class window = [NSWindow class];
  Class decoration = [GSWindowDecorationView class];

  GSWindowTabbingWrapMethod(window, @selector(orderWindow:relativeTo:),
    (IMP)GSTabbingOrderWindow, &originalOrderWindow);
  GSWindowTabbingWrapMethod(window, @selector(setTitle:),
    (IMP)GSTabbingSetTitle, &originalSetTitle);
  GSWindowTabbingWrapMethod(window,
    @selector(setTitleWithRepresentedFilename:),
    (IMP)GSTabbingSetTitleWithRepresentedFilename,
    &originalSetTitleWithRepresentedFilename);
  GSWindowTabbingWrapMethod(window, @selector(setDocumentEdited:),
    (IMP)GSTabbingSetDocumentEdited, &originalSetDocumentEdited);
  GSWindowTabbingWrapMethod(window, @selector(sendEvent:),
    (IMP)GSTabbingSendEvent, &originalSendEvent);
  GSWindowTabbingWrapMethod(window, @selector(performKeyEquivalent:),
    (IMP)GSTabbingPerformKeyEquivalent, &originalPerformKeyEquivalent);
  GSWindowTabbingWrapMethod(window, @selector(close),
    (IMP)GSTabbingClose, &originalClose);
  GSWindowTabbingWrapMethod(window, @selector(validateUserInterfaceItem:),
    (IMP)GSTabbingValidateUserInterfaceItem,
    &originalValidateUserInterfaceItem);
  GSWindowTabbingWrapMethod(window, @selector(dealloc),
    (IMP)GSTabbingWindowDealloc, &originalWindowDealloc);
  GSWindowTabbingWrapMethod(decoration, @selector(layout),
    (IMP)GSTabbingDecorationLayout, &originalDecorationLayout);
  GSWindowTabbingWrapMethod(decoration,
    @selector(contentRectForFrameRect:styleMask:),
    (IMP)GSTabbingContentRectForFrameRect, &originalContentRectForFrameRect);
  GSWindowTabbingWrapMethod(decoration,
    @selector(frameRectForContentRect:styleMask:),
    (IMP)GSTabbingFrameRectForContentRect, &originalFrameRectForContentRect);
}

#endif /* GS_HAS_WINDOW_TABBING */


/* The public functions. */

NSView *
GSWindowTabBarViewForWindow(NSWindow *window)
{
#ifdef GS_HAS_WINDOW_TABBING
  return nil;
#else /* not GS_HAS_WINDOW_TABBING */
  if (GSWindowTabbingClassesAreOurs() == NO)
    {
      return [GSWindowTabbingState _tabBarViewForWindow: window];
    }
  if (installed == NO)
    {
      return nil;
    }
  return [window _tabBarView];
#endif /* GS_HAS_WINDOW_TABBING */
}

BOOL
GSWindowTabbingInstall(void)
{
#ifdef GS_HAS_WINDOW_TABBING
  return NO;
#else /* not GS_HAS_WINDOW_TABBING */
  Class window;

  if (installed)
    {
      return YES;
    }
  if (GSWindowTabbingClassesAreOurs() == NO)
    {
      return [GSWindowTabbingState _installTabbing];
    }
  if ([NSWindow instancesRespondToSelector:
                 @selector(addTabbedWindow:ordered:)])
    {
      /* Native tabbing (or another copy of this code): nothing to do. */
      return NO;
    }
  installed = YES;
  states = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
                            NSObjectMapValueCallBacks, 64);

  window = [NSWindow class];
  GSWindowTabbingAddMissingMethods(NSClassFromString(@"GSWindowTabbingWindow"),
                                   window);
  /* The class methods: the donor's metaclass to NSWindow's. */
  GSWindowTabbingAddMissingMethods(
    object_getClass(NSClassFromString(@"GSWindowTabbingWindow")),
    object_getClass(window));
  GSWindowTabbingAddMissingMethods(
    NSClassFromString(@"GSWindowTabbingDecorationView"),
    [GSWindowDecorationView class]);
  GSWindowTabbingAddMissingMethods(NSClassFromString(@"GSWindowTabbingTheme"),
                                   [GSTheme class]);
  GSWindowTabbingWrapMethods();
  return YES;
#endif /* GS_HAS_WINDOW_TABBING */
}
