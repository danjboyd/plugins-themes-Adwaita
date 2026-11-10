/* Copyright (C) 2026 Daniel Boyd

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

/* -ProbeOnly design-surfaces (make check-design-surfaces): Gorm's design
   windows with GnomeThemeDesignSurfaces (#26). Run as Gorm runs, with
   compact metrics. GormNSWindow is a stand-in here, with Gorm's class
   name: the theme looks the class up by name. With the default on, a
   button and a tab view in it get GNOME's margins and tab height while the
   same in an ordinary window stay compact; with it off, both are compact.
   Either way the fonts are the ones the controls were given, and a
   control's archive is the same before and after it is drawn in the
   design window: what Gorm saves doesn't change. */

#import "QuirkProbe.h"

#import <GNUstepGUI/GSTheme.h>

@interface GormNSWindow : NSWindow
@end

@implementation GormNSWindow
@end

@interface QuirkProbe (DesignSurfacesResults)
- (void) pass: (NSString *)ident detail: (NSString *)detail;
- (void) fail: (NSString *)ident detail: (NSString *)detail;
@end

static NSWindow *
QuirkProbeDesignWindow(Class class, NSString *title, NSButton **buttonOut, NSTabView **tabViewOut)
{
  NSWindow *window = [[class alloc] initWithContentRect: NSMakeRect (100, 100, 320, 200)
                                              styleMask: NSTitledWindowMask
                                                backing: NSBackingStoreBuffered
                                                  defer: NO];
  NSButton *button = AUTORELEASE ([[NSButton alloc] initWithFrame: NSMakeRect (10, 10, 120, 32)]);
  NSTabView *tabView = AUTORELEASE ([[NSTabView alloc] initWithFrame: NSMakeRect (10, 50, 300, 140)]);
  NSTabViewItem *item = AUTORELEASE ([[NSTabViewItem alloc] initWithIdentifier: @"one"]);

  [window setTitle: title];
  [button setTitle: @"Apply"];
  [button setBezelStyle: NSRoundedBezelStyle];
  [[window contentView] addSubview: button];
  [item setLabel: @"Attributes"];
  [tabView addTabViewItem: item];
  [[window contentView] addSubview: tabView];
  *buttonOut = button;
  *tabViewOut = tabView;
  return AUTORELEASE (window);
}

static CGFloat
QuirkProbeDesignMargin(NSButton *button)
{
  return [[GSTheme theme] buttonMarginsForCell: [button cell]
                                         style: NSRoundedBezelStyle
                                         state: GSThemeNormalState].left;
}

/* "font 12, margin 0, cell 61x24, tab content 292x105" */
static NSString *
QuirkProbeDesignDescription(NSButton *button, NSTabView *tabView)
{
  NSSize cellSize = [[button cell] cellSize];

  return [NSString stringWithFormat: @"font %g, margin %g, cell %gx%g, tab content %gx%g",
    [[button font] pointSize], QuirkProbeDesignMargin (button),
    cellSize.width, cellSize.height,
    NSWidth ([tabView contentRect]), NSHeight ([tabView contentRect])];
}

@implementation QuirkProbe (DesignSurfaces)

- (void) checkDesignSurfaces
{
  BOOL on = [[NSUserDefaults standardUserDefaults] boolForKey: @"GnomeThemeDesignSurfaces"];
  NSButton *designButton, *plainButton;
  NSTabView *designTabView, *plainTabView;
  NSWindow *design = QuirkProbeDesignWindow ([GormNSWindow class], @"QuirkProbe Design Surface",
                                             &designButton, &designTabView);
  NSWindow *plain = QuirkProbeDesignWindow ([NSWindow class], @"QuirkProbe Gorm Panel",
                                            &plainButton, &plainTabView);
  NSButton *loose = AUTORELEASE ([[NSButton alloc] initWithFrame: NSMakeRect (10, 10, 120, 32)]);
  NSData *before, *after;
  NSString *detail;
  BOOL ok;

  [design orderFront: nil];
  [plain orderFront: nil];
  [design display];
  [plain display];

  detail = [NSString stringWithFormat: @"design surfaces %@: design window %@; ordinary window %@",
    on ? @"on" : @"off",
    QuirkProbeDesignDescription (designButton, designTabView),
    QuirkProbeDesignDescription (plainButton, plainTabView)];
  if (on)
    {
      /* GNOME's margins and taller tab row in the design window only. */
      ok = QuirkProbeDesignMargin (designButton) > QuirkProbeDesignMargin (plainButton)
        && [[designButton cell] cellSize].height > [[plainButton cell] cellSize].height
        && NSHeight ([designTabView contentRect]) < NSHeight ([plainTabView contentRect]);
    }
  else
    {
      ok = fabs (QuirkProbeDesignMargin (designButton) - QuirkProbeDesignMargin (plainButton)) < 0.01
        && NSEqualSizes ([[designButton cell] cellSize], [[plainButton cell] cellSize])
        && NSEqualRects ([designTabView contentRect], [plainTabView contentRect]);
    }
  if (ok)
    {
      [self pass: @"design-surface-metrics" detail: detail];
    }
  else
    {
      [self fail: @"design-surface-metrics" detail: detail];
    }

  /* The fonts the controls were given, in both windows. */
  if (fabs ([[designButton font] pointSize] - [[plainButton font] pointSize]) < 0.01)
    {
      [self pass: @"design-surface-fonts"
          detail: [NSString stringWithFormat: @"both %gpt", [[designButton font] pointSize]]];
    }
  else
    {
      [self fail: @"design-surface-fonts"
          detail: [NSString stringWithFormat: @"design %gpt, ordinary %gpt",
                     [[designButton font] pointSize], [[plainButton font] pointSize]]];
    }

  /* What Gorm would save: a control's archive, before it is in the design
     window and after it has been sized and drawn there. */
  [loose setTitle: @"Apply"];
  [loose setBezelStyle: NSRoundedBezelStyle];
  before = [NSArchiver archivedDataWithRootObject: loose];
  [[design contentView] addSubview: loose];
  [[loose cell] cellSize];
  [design display];
  [loose removeFromSuperview];
  after = [NSArchiver archivedDataWithRootObject: loose];
  if ([before isEqualToData: after])
    {
      [self pass: @"design-surface-archive"
          detail: [NSString stringWithFormat: @"%lu bytes, the same", (unsigned long)[before length]]];
    }
  else
    {
      [self fail: @"design-surface-archive"
          detail: [NSString stringWithFormat: @"%lu bytes before, %lu after",
                     (unsigned long)[before length], (unsigned long)[after length]]];
    }

  [design orderOut: nil];
  [plain orderOut: nil];
}

@end
