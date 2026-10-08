/** <title>GSWindowTabbingWindow</title>

   <abstract>NSWindow's tabbing methods.</abstract>

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

/* These are NSWindow's methods.  Upstream they go into NSWindow.m's
   @implementation NSWindow as they are, with the tabbing state as
   instance variables instead of GSWindowTabbingStateForWindow().  Here
   they are written in GSWindowTabbingWindow, a subclass of NSWindow that
   is never instantiated: GSWindowTabbingInstall() copies its methods
   into NSWindow (only those NSWindow doesn't have), so self is always an
   NSWindow.  For that reason none of them may use super. */

#import "GSWindowTabbingPrivate.h"
#import "GSWindowTabBarView.h"

#ifndef GS_HAS_WINDOW_TABBING

NSString *const GSWindowTabBarDidChangeNotification
  = @"GSWindowTabBarDidChangeNotification";

/* +allowsAutomaticWindowTabbing. */
static BOOL allowsAutomaticTabbing = YES;
/* Nonzero while a group orders its own windows in and out: those orders
   must not select tabs or join groups. */
static int internalOrdering = 0;
/* The window whose "+" button is asking for a new tab: the next window
   ordered in for the first time joins its group. */
static NSWindow *newTabWindow = nil;

@interface NSWindow (GSWindowTabbingLibsGUI)
/* libs-gui's: the window's decoration view. */
- (NSView *) _windowView;
@end

@interface GSWindowTabbingWindow : NSWindow
@end

/* Private helpers, used before they are defined. */
@interface GSWindowTabbingWindow (Helpers)
- (BOOL) _canBeTabbed;
- (BOOL) _canBeTabbedWith: (NSWindow *)other;
- (NSWindow *) _keyWindowForTabbing;
- (NSWindow *) _windowToJoinAsTab;
- (BOOL) _tabbingSelectsSelfInGroup;
- (BOOL) _tabbingJoinsGroupWhenFirstShown;
- (void) _updateTabBar;
- (void) _redrawTabBars;
- (BOOL) _hasWindowToMerge;
@end

@implementation GSWindowTabbingWindow

/* The public API. */

+ (BOOL) allowsAutomaticWindowTabbing
{
  return allowsAutomaticTabbing;
}

+ (void) setAllowsAutomaticWindowTabbing: (BOOL)flag
{
  allowsAutomaticTabbing = flag;
}

/* AppleWindowTabbingMode, as on macOS: "always", "manual", or unset
   (in full screen; GNUstep has no full-screen spaces, so in effect
   manual). */
+ (NSWindowUserTabbingPreference) userTabbingPreference
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

- (NSWindowTabbingMode) tabbingMode
{
  GSWindowTabbingState *state = GSWindowTabbingStateForWindow(self, NO);

  return (state != nil) ? state->mode : NSWindowTabbingModeAutomatic;
}

- (void) setTabbingMode: (NSWindowTabbingMode)mode
{
  GSWindowTabbingStateForWindow(self, YES)->mode = mode;
}

/* By default the window's class: windows of one kind tab together, as
   on macOS. */
- (NSWindowTabbingIdentifier) tabbingIdentifier
{
  GSWindowTabbingState *state = GSWindowTabbingStateForWindow(self, NO);

  if (state != nil && state->identifier != nil)
    {
      return state->identifier;
    }
  return NSStringFromClass([self class]);
}

- (void) setTabbingIdentifier: (NSWindowTabbingIdentifier)identifier
{
  ASSIGNCOPY(GSWindowTabbingStateForWindow(self, YES)->identifier,
             identifier);
}

- (NSWindowTabGroup *) tabGroup
{
  GSWindowTabbingState *state = GSWindowTabbingStateForWindow(self, YES);
  NSWindowTabGroup *group;

  if (state->group == nil)
    {
      group = [[NSWindowTabGroup alloc]
                initWithIdentifier: [self tabbingIdentifier]];
      [group addWindow: self];
      RELEASE(group);
    }
  return state->group;
}

- (NSArray *) tabbedWindows
{
  NSWindowTabGroup *group = [self _tabbingGroup];

  if (group == nil || [[group windows] count] < 2)
    {
      return nil;
    }
  return [group windows];
}

- (NSWindowTab *) tab
{
  GSWindowTabbingState *state = GSWindowTabbingStateForWindow(self, YES);

  if (state->tab == nil)
    {
      state->tab = [[NSWindowTab alloc] initWithWindow: self];
    }
  return state->tab;
}

- (void) addTabbedWindow: (NSWindow *)window
                 ordered: (NSWindowOrderingMode)ordered
{
  NSWindowTabGroup *group;
  NSUInteger index;

  if (window == nil || window == self)
    {
      return;
    }
  group = [self tabGroup];
  index = [[group windows] indexOfObjectIdenticalTo: self];
  if (ordered != NSWindowBelow)
    {
      index++;
    }
  GSWindowTabbingStateForWindow(window, YES)->shown = YES;
  [group insertWindow: window atIndex: index];
}

- (IBAction) selectNextTab: (id)sender
{
  [[self tabGroup] _selectNextTab: YES];
}

- (IBAction) selectPreviousTab: (id)sender
{
  [[self tabGroup] _selectNextTab: NO];
}

- (IBAction) moveTabToNewWindow: (id)sender
{
  NSWindowTabGroup *group = [self tabGroup];
  NSRect frame;

  if ([[group windows] count] < 2)
    {
      return;
    }
  frame = [self frame];
  [group removeWindow: self];
  /* A little below and to the right of the group, as macOS places it. */
  frame.origin.x += 30.0;
  frame.origin.y -= 30.0;
  internalOrdering++;
  [self setFrame: frame display: NO];
  [self makeKeyAndOrderFront: nil];
  internalOrdering--;
}

/* A window that has been on screen, or is in a group, joins; windows
   the app keeps hidden and has never shown stay out. */
- (IBAction) mergeAllWindows: (id)sender
{
  NSArray *windows = [NSApp windows];
  NSWindowTabGroup *group = [self tabGroup];
  NSUInteger i;

  for (i = 0; i < [windows count]; i++)
    {
      NSWindow *window = [windows objectAtIndex: i];

      if (window == self || [self _canBeTabbedWith: window] == NO
        || [[group windows] indexOfObjectIdenticalTo: window] != NSNotFound)
        {
          continue;
        }
      if ([window isVisible] || [window _tabbingGroup] != nil)
        {
          [group addWindow: window];
        }
    }
  [group setSelectedWindow: self];
}

- (IBAction) toggleTabBar: (id)sender
{
  [[self tabGroup] _toggleTabBar];
}


/* GSWindowTabbable: how the tab group moves its windows. */

- (void) _tabbingShowWithFrame: (NSRect)frame makeKey: (BOOL)makeKey
{
  internalOrdering++;
  [self setFrame: frame display: NO];
  if (makeKey)
    {
      [self makeKeyAndOrderFront: nil];
    }
  else
    {
      [self orderFront: nil];
    }
  internalOrdering--;
}

- (void) _tabbingHide
{
  internalOrdering++;
  [self orderOut: nil];
  internalOrdering--;
}

- (void) _tabbingGroupDidChange
{
  [self _updateTabBar];
}

- (NSWindowTabGroup *) _tabbingGroup
{
  GSWindowTabbingState *state = GSWindowTabbingStateForWindow(self, NO);

  return (state != nil) ? state->group : nil;
}

- (void) _setTabbingGroup: (NSWindowTabGroup *)group
{
  ASSIGN(GSWindowTabbingStateForWindow(self, YES)->group, group);
}


/* What NSWindow's own methods do for tabbing (see
   GSWindowTabbingPrivate.h for where each is called). */

- (BOOL) _tabbingOrderWindow: (NSWindowOrderingMode)place
{
  if (place == NSWindowOut)
    {
      return NO;
    }
  if (internalOrdering == 0)
    {
      if ([self _tabbingSelectsSelfInGroup]
        || [self _tabbingJoinsGroupWhenFirstShown])
        {
          return YES;
        }
    }
  GSWindowTabbingStateForWindow(self, YES)->shown = YES;
  return NO;
}

- (void) _tabbingTitleDidChange
{
  [self _redrawTabBars];
}

/* Ctrl+Tab and Ctrl+Page Down select the next tab, Ctrl+Shift+Tab and
   Ctrl+Page Up the previous one, as in GNOME's apps, while the window is
   in a group with other tabs.  They are taken before the first responder
   sees them: a text view would insert a tab or scroll, and the window's
   own key view loop would take Ctrl+Tab. */
- (BOOL) _tabbingHandleKeyEvent: (NSEvent *)event
{
  NSUInteger flags;
  NSString *characters;
  unichar c;
  BOOL shift;

  if ([event type] != NSKeyDown || [[self tabbedWindows] count] < 2)
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
      [self selectNextTab: nil];
      return YES;
    }
  /* 0x19 is Shift+Tab (back tab) as some keyboards send it. */
  if ((c == '\t' && shift) || c == 0x19 || c == NSPageUpFunctionKey)
    {
      [self selectPreviousTab: nil];
      return YES;
    }
  return NO;
}

/* Closing the selected tab shows its neighbour first, so the app never
   sees a moment with no window on screen: NSApplication decides at
   NSWindowWillCloseNotification, from the windows on screen, whether the
   last window closed (and so whether to terminate, for apps whose
   -applicationShouldTerminateAfterLastWindowClosed: says YES).  The
   window leaves its group before it closes. */
- (void) _tabbingWillClose
{
  NSWindowTabGroup *group = RETAIN([self _tabbingGroup]);

  if (group != nil && [[group windows] count] > 1)
    {
      [group removeWindow: self];
    }
  else if (group != nil)
    {
      [group _windowWillLeave: self];
      [self _setTabbingGroup: nil];
    }
  RELEASE(group);
}

- (BOOL) _tabbingValidateUserInterfaceItem: (id)item valid: (BOOL *)valid
{
  SEL action = [item action];

  if (sel_isEqual(action, @selector(selectNextTab:))
    || sel_isEqual(action, @selector(selectPreviousTab:))
    || sel_isEqual(action, @selector(moveTabToNewWindow:)))
    {
      *valid = ([[self tabbedWindows] count] > 1);
      return YES;
    }
  if (sel_isEqual(action, @selector(toggleTabBar:)))
    {
      *valid = [self _canBeTabbed];
      if (*valid && [item isKindOfClass: [NSMenuItem class]])
        {
          /* The item says what it will do, as macOS's does. */
          [(NSMenuItem *)item setTitle: [[self tabGroup] isTabBarVisible]
            ? @"Hide Tab Bar" : @"Show Tab Bar"];
        }
      return YES;
    }
  if (sel_isEqual(action, @selector(mergeAllWindows:)))
    {
      *valid = [self _canBeTabbed] && [self _hasWindowToMerge];
      return YES;
    }
  return NO;
}

- (void) _tabbingDealloc
{
  if (newTabWindow == self)
    {
      newTabWindow = nil;
    }
  GSWindowTabbingForgetWindow(self);
}

- (CGFloat) _tabBarReservedHeight
{
  NSWindowTabGroup *group = [self _tabbingGroup];
  GSTheme *theme;

  if (group == nil || [group isTabBarVisible] == NO)
    {
      return 0.0;
    }
  theme = [GSTheme theme];
  if ([theme windowTabBarPlacementForWindow: self]
    != GSWindowTabBarAboveContent)
    {
      return 0.0;
    }
  return [theme windowTabBarHeightForWindow: self];
}

- (GSWindowTabBarView *) _tabBarView
{
  GSWindowTabbingState *state = GSWindowTabbingStateForWindow(self, NO);

  if (state == nil || state->group == nil
    || [state->group isTabBarVisible] == NO)
    {
      return nil;
    }
  return state->barView;
}

- (BOOL) _tabbingCanCreateNewTab
{
  return [NSApp targetForAction: @selector(newWindowForTab:)
                             to: nil
                           from: self] != nil;
}

- (void) _tabbingCreateNewTab
{
  newTabWindow = self;
  [NSApp sendAction: @selector(newWindowForTab:) to: nil from: self];
  newTabWindow = nil;
}

@end


@implementation GSWindowTabbingWindow (Helpers)

/* Titled windows that aren't panels can be tabs, as on macOS. */
- (BOOL) _canBeTabbed
{
  return [self isKindOfClass: [NSPanel class]] == NO
    && ([self styleMask] & NSTitledWindowMask) != 0
    && [self tabbingMode] != NSWindowTabbingModeDisallowed;
}

- (BOOL) _canBeTabbedWith: (NSWindow *)other
{
  return [(GSWindowTabbingWindow *)other _canBeTabbed]
    && [[other tabbingIdentifier] isEqual: [self tabbingIdentifier]];
}

/* The window a new window joins with automatic tabbing: the key window.
   While the app isn't active NSApp has none, so then the window that
   says it is key, the main window, or else the frontmost window this one
   can be tabbed with. */
- (NSWindow *) _keyWindowForTabbing
{
  NSWindow *key = [NSApp keyWindow];
  NSArray *ordered;
  NSUInteger i;

  if (key != nil)
    {
      return key;
    }
  ordered = [NSApp orderedWindows];
  for (i = 0; i < [ordered count]; i++)
    {
      if ([[ordered objectAtIndex: i] isKeyWindow])
        {
          return [ordered objectAtIndex: i];
        }
    }
  key = [NSApp mainWindow];
  if (key != nil)
    {
      return key;
    }
  for (i = 0; i < [ordered count]; i++)
    {
      NSWindow *candidate = [ordered objectAtIndex: i];

      if (candidate != self && [candidate isVisible]
        && [self _canBeTabbedWith: candidate])
        {
          return candidate;
        }
    }
  return nil;
}

/* The window a new window ordered in for the first time joins, if any:
   the "+" button's window, or with automatic tabbing the key window. */
- (NSWindow *) _windowToJoinAsTab
{
  NSWindow *key;

  if ([self _canBeTabbed] == NO)
    {
      return nil;
    }
  if (newTabWindow != nil && newTabWindow != self)
    {
      return newTabWindow;
    }
  if ([self tabbingMode] == NSWindowTabbingModeAutomatic
    && ([NSWindow allowsAutomaticWindowTabbing] == NO
      || [NSWindow userTabbingPreference]
        != NSWindowUserTabbingPreferenceAlways))
    {
      return nil;
    }
  key = [self _keyWindowForTabbing];
  if (key == nil || key == self || [key isVisible] == NO
    || [self _canBeTabbedWith: key] == NO)
    {
      return nil;
    }
  return key;
}

/* A hidden tab ordered in (by the Windows menu, or
   -makeKeyAndOrderFront:) becomes its group's selected tab instead.  YES
   if it did. */
- (BOOL) _tabbingSelectsSelfInGroup
{
  NSWindowTabGroup *group = [self _tabbingGroup];

  if (group != nil && [[group windows] count] > 1
    && [group selectedWindow] != self)
    {
      [group setSelectedWindow: self];
      return YES;
    }
  return NO;
}

/* A window shown for the first time joins the window it should be a tab
   of, if any.  YES if it did. */
- (BOOL) _tabbingJoinsGroupWhenFirstShown
{
  GSWindowTabbingState *state = GSWindowTabbingStateForWindow(self, NO);
  NSWindow *join;

  if ((state != nil && state->shown) || [self isVisible])
    {
      return NO;
    }
  join = [self _windowToJoinAsTab];
  GSWindowTabbingStateForWindow(self, YES)->shown = YES;
  if (join == nil)
    {
      return NO;
    }
  [join addTabbedWindow: self ordered: NSWindowAbove];
  return YES;
}

/* Puts the bar in the window or takes it out, and lays the window out
   again: the window keeps its frame, and the content gives up or takes
   back the bar's row. */
- (void) _updateTabBar
{
  GSWindowTabbingState *state = GSWindowTabbingStateForWindow(self, NO);
  NSView *decoration = [self _windowView];
  BOOL visible = (state != nil && state->group != nil
    && [state->group isTabBarVisible]);

  if (visible)
    {
      if (state->barView == nil)
        {
          state->barView = [[GSWindowTabBarView alloc] initWithWindow: self];
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
    postNotificationName: GSWindowTabBarDidChangeNotification
                  object: self];
}

/* A tab's title or edited state changed: every bar of the group shows
   it (the selected window's bar is the one on screen). */
- (void) _redrawTabBars
{
  NSArray *windows = [[self _tabbingGroup] windows];
  NSUInteger i;

  for (i = 0; i < [windows count]; i++)
    {
      GSWindowTabbingState *other;

      other = GSWindowTabbingStateForWindow([windows objectAtIndex: i], NO);
      if (other != nil && other->barView != nil)
        {
          [other->barView tabsDidChange];
        }
    }
}

/* Is there a window on screen -mergeAllWindows: would add? */
- (BOOL) _hasWindowToMerge
{
  NSArray *windows = [NSApp windows];
  NSArray *tabs = [[self tabGroup] windows];
  NSUInteger i;

  for (i = 0; i < [windows count]; i++)
    {
      NSWindow *window = [windows objectAtIndex: i];

      if (window != self && [window isVisible]
        && [self _canBeTabbedWith: window]
        && [tabs indexOfObjectIdenticalTo: window] == NSNotFound)
        {
          return YES;
        }
    }
  return NO;
}

@end

#endif /* GS_HAS_WINDOW_TABBING */
