/* GSWindowTabGroup.m: NSWindowTabGroup and NSWindowTab, the model.

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

#import "GSWindowTabbingPrivate.h"
#import "GSWindowTabBarView.h"

CGFloat
GSWindowTabWidth (NSUInteger count, CGFloat width, CGFloat minimum, CGFloat maximum)
{
  CGFloat each;

  if (count == 0)
    {
      return 0.0;
    }
  each = floor (width / count);
  if (maximum > 0.0 && each > maximum)
    {
      each = maximum;
    }
  if (each < minimum)
    {
      each = minimum;
    }
  return each;
}


#ifndef GS_HAS_WINDOW_TABBING

/* The group's windows are kept as non-retained pointers: a window on
   its own is not held by its group. With two or more, the group retains
   them all, as the hidden ones have nothing else showing them. */
static id
GSTabWindowAt (NSArray *windows, NSUInteger index)
{
  return [[windows objectAtIndex: index] nonretainedObjectValue];
}

@implementation NSWindowTabGroup

- (id) init
{
  return [self initWithIdentifier: nil];
}

- (id) initWithIdentifier: (NSString *)identifier
{
  if ((self = [super init]) != nil)
    {
      ASSIGNCOPY (_identifier, identifier);
      _windows = [NSMutableArray new];
      _selectedWindow = nil;
      _barState = GSWindowTabBarAutomatic;
      _retainsWindows = NO;
    }
  return self;
}

- (void) dealloc
{
  NSUInteger i;

  if (_retainsWindows)
    {
      for (i = 0; i < [_windows count]; i++)
        {
          RELEASE (GSTabWindowAt (_windows, i));
        }
    }
  RELEASE (_windows);
  RELEASE (_identifier);
  [super dealloc];
}

- (NSWindowTabbingIdentifier) identifier
{
  return _identifier;
}

- (NSArray *) windows
{
  NSMutableArray *windows = [NSMutableArray arrayWithCapacity: [_windows count]];
  NSUInteger i;

  for (i = 0; i < [_windows count]; i++)
    {
      [windows addObject: GSTabWindowAt (_windows, i)];
    }
  return windows;
}

- (NSUInteger) indexOfWindow: (id)window
{
  NSUInteger i;

  for (i = 0; i < [_windows count]; i++)
    {
      if (GSTabWindowAt (_windows, i) == window)
        {
          return i;
        }
    }
  return NSNotFound;
}

- (NSWindow *) selectedWindow
{
  return _selectedWindow;
}

/* Retain the windows while there are two or more. */
- (void) updateRetention
{
  BOOL retain = ([_windows count] > 1);
  NSUInteger i;

  if (retain == _retainsWindows)
    {
      return;
    }
  _retainsWindows = retain;
  for (i = 0; i < [_windows count]; i++)
    {
      if (retain)
        {
          RETAIN (GSTabWindowAt (_windows, i));
        }
      else
        {
          RELEASE (GSTabWindowAt (_windows, i));
        }
    }
}

- (void) notifyWindows: (id)extra
{
  NSArray *windows = [self windows];
  NSUInteger i;

  for (i = 0; i < [windows count]; i++)
    {
      [[windows objectAtIndex: i] gsTabGroupDidChange];
    }
  if (extra != nil && [windows indexOfObjectIdenticalTo: extra] == NSNotFound)
    {
      [extra gsTabGroupDidChange];
    }
}

/* Shows window in place of the selected one: at its frame, and key if
   it was. */
- (void) switchToWindow: (id)window
{
  id previous = _selectedWindow;

  if (window == previous)
    {
      return;
    }
  _selectedWindow = window;
  if (previous != nil)
    {
      NSRect frame = [previous frame];
      BOOL key = [previous isKeyWindow];

      [previous gsTabHide];
      [window gsTabShowWithFrame: frame makeKey: key];
    }
}

- (void) setSelectedWindow: (NSWindow *)window
{
  if (window == nil || [self indexOfWindow: window] == NSNotFound
    || window == _selectedWindow)
    {
      return;
    }
  [self switchToWindow: window];
  [self notifyWindows: nil];
}

- (BOOL) isTabBarVisible
{
  switch (_barState)
    {
      case GSWindowTabBarShown:
        return YES;
      case GSWindowTabBarHidden:
        return NO;
      default:
        return [_windows count] > 1;
    }
}

- (BOOL) isOverviewVisible
{
  return NO;
}

- (void) setOverviewVisible: (BOOL)flag
{
  /* No overview yet. */
}

- (void) addWindow: (NSWindow *)window
{
  [self insertWindow: window atIndex: [_windows count]];
}

/* The window joins at index and becomes the selected tab. */
- (void) insertWindow: (NSWindow *)window atIndex: (NSInteger)index
{
  id old;
  NSUInteger current;

  if (window == nil)
    {
      return;
    }
  current = [self indexOfWindow: window];
  if (current != NSNotFound)
    {
      /* Already here: only its place changes. */
      NSValue *value = RETAIN ([_windows objectAtIndex: current]);

      [_windows removeObjectAtIndex: current];
      index = MAX (0, MIN (index, (NSInteger)[_windows count]));
      [_windows insertObject: value atIndex: index];
      RELEASE (value);
      [self notifyWindows: nil];
      return;
    }

  /* Keep the window alive while it moves between groups. */
  RETAIN (window);
  old = [(id)window gsTabGroup];
  if (old != nil && old != self)
    {
      [old gsWindowWillLeave: window];
    }
  if (_identifier == nil)
    {
      ASSIGNCOPY (_identifier, [(id)window tabbingIdentifier]);
    }
  index = MAX (0, MIN (index, (NSInteger)[_windows count]));
  [_windows insertObject: [NSValue valueWithNonretainedObject: window]
                 atIndex: index];
  if (_retainsWindows)
    {
      RETAIN (window);
    }
  [self updateRetention];
  [(id)window gsSetTabGroup: self];
  if (_selectedWindow == nil)
    {
      _selectedWindow = window;
    }
  else
    {
      [self switchToWindow: window];
    }
  [self notifyWindows: nil];
  RELEASE (window);
}

- (void) removeWindow: (NSWindow *)window
{
  if (window == nil || [self indexOfWindow: window] == NSNotFound)
    {
      return;
    }
  RETAIN (window);
  [self gsWindowWillLeave: window];
  [(id)window gsSetTabGroup: nil];
  [(id)window gsTabGroupDidChange];
  RELEASE (window);
}

- (void) gsWindowWillLeave: (id)window
{
  NSUInteger index = [self indexOfWindow: window];

  if (index == NSNotFound)
    {
      return;
    }
  RETAIN (self);
  if (window == _selectedWindow)
    {
      NSUInteger count = [_windows count];

      if (count > 1)
        {
          /* Its neighbour: the next tab, or the previous for the last. */
          id neighbour = GSTabWindowAt (_windows, (index + 1 < count) ? index + 1 : index - 1);
          NSRect frame = [window frame];
          BOOL key = [window isKeyWindow];

          _selectedWindow = neighbour;
          [neighbour gsTabShowWithFrame: frame makeKey: key];
        }
      else
        {
          _selectedWindow = nil;
        }
    }
  [_windows removeObjectAtIndex: index];
  if (_retainsWindows)
    {
      /* Balanced by the caller's retain, or the window is released by
         whoever closed it. */
      AUTORELEASE (window);
    }
  [self updateRetention];
  [self notifyWindows: window];
  RELEASE (self);
}

/* Shows or hides the bar; back to automatic when that's what automatic
   would do (hidden, then shown again, with two tabs). */
- (void) gsToggleTabBar
{
  BOOL show = ([self isTabBarVisible] == NO);

  if (show == ([_windows count] > 1))
    {
      _barState = GSWindowTabBarAutomatic;
    }
  else
    {
      _barState = show ? GSWindowTabBarShown : GSWindowTabBarHidden;
    }
  [self notifyWindows: nil];
}

- (void) gsSelectNextTab: (BOOL)forward
{
  NSUInteger count = [_windows count];
  NSUInteger index;

  if (count < 2)
    {
      return;
    }
  index = [self indexOfWindow: _selectedWindow];
  if (index == NSNotFound)
    {
      index = 0;
    }
  index = forward ? (index + 1) % count : (index + count - 1) % count;
  [self setSelectedWindow: GSTabWindowAt (_windows, index)];
}

- (NSString *) description
{
  return [NSString stringWithFormat: @"<%@ %p identifier %@, %lu window(s)>",
                   NSStringFromClass ([self class]), self, _identifier,
                   (unsigned long)[_windows count]];
}

@end


@implementation NSWindowTab

- (id) initWithWindow: (NSWindow *)window
{
  if ((self = [super init]) != nil)
    {
      _window = window;
    }
  return self;
}

- (void) dealloc
{
  RELEASE (_title);
  RELEASE (_attributedTitle);
  RELEASE (_toolTip);
  RELEASE (_accessoryView);
  [super dealloc];
}

- (void) changed
{
  [(id)_window gsTabGroupDidChange];
}

- (NSString *) title
{
  NSString *filename;

  if (_title != nil)
    {
      return _title;
    }
  if (_attributedTitle != nil)
    {
      return [_attributedTitle string];
    }
  /* A document's file name, as macOS shows it: GNUstep's
     -setTitleWithRepresentedFilename: also puts its folder in the
     window's title ("Notes.txt  --  /tmp"). Only while the title is that
     one: GNUstep's default represented filename is "Window", and a title
     the app sets afterwards wins. */
  filename = [(id <GSWindowTabbable>)_window representedFilename];
  if ([filename length] > 0)
    {
      NSString *name = [filename lastPathComponent];
      NSString *fileTitle = [NSString stringWithFormat: @"%@  --  %@", name,
        [[filename stringByDeletingLastPathComponent] stringByAbbreviatingWithTildeInPath]];

      if ([[_window title] isEqualToString: fileTitle])
        {
          return name;
        }
    }
  return [_window title];
}

- (void) setTitle: (NSString *)title
{
  ASSIGNCOPY (_title, title);
  [self changed];
}

- (NSAttributedString *) attributedTitle
{
  return _attributedTitle;
}

- (void) setAttributedTitle: (NSAttributedString *)title
{
  ASSIGNCOPY (_attributedTitle, title);
  [self changed];
}

- (NSString *) toolTip
{
  return _toolTip;
}

- (void) setToolTip: (NSString *)toolTip
{
  ASSIGNCOPY (_toolTip, toolTip);
  [self changed];
}

- (NSView *) accessoryView
{
  return _accessoryView;
}

- (void) setAccessoryView: (NSView *)view
{
  ASSIGN (_accessoryView, view);
  [self changed];
}

@end

#endif /* GS_HAS_WINDOW_TABBING */
