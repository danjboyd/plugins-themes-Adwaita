/*
   Copyright (C) 2026 Daniel Boyd

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

/* GNOME's settings followed while the app runs (#64): the probe changes
   its own GSettings keyfile (the run's scratch XDG_CONFIG_HOME, with
   GSETTINGS_BACKEND=keyfile), waits for the theme to hear it, and
   measures. Dark style and Large Text on, then off again. */

#import "QuirkProbe.h"

#import <GNUstepGUI/GSTheme.h>

@interface QuirkProbe (LiveSettingsResults)
- (void) pass: (NSString *)ident detail: (NSString *)detail;
- (void) fail: (NSString *)ident detail: (NSString *)detail;
- (void) skip: (NSString *)ident detail: (NSString *)detail;
- (void) liveSettingsResult: (BOOL)ok ident: (NSString *)ident detail: (NSString *)detail;
- (void) checkLiveButtonLayout: (NSWindow *)window keyfile: (NSString *)path original: (NSString *)original;
@end

static BOOL QuirkProbeLiveSettingsHeard = NO;

@interface QuirkProbeLiveSettingsListener : NSObject
+ (void) heard: (NSNotification *)notification;
@end

@implementation QuirkProbeLiveSettingsListener
+ (void) heard: (NSNotification *)notification
{
  QuirkProbeLiveSettingsHeard = YES;
}
@end

/* The keyfile with key=value set in its [section] (replacing the line). */
static NSString *
QuirkProbeKeyfileSetting(NSString *keyfile, NSString *key, NSString *value)
{
  NSMutableArray *lines = [[[keyfile componentsSeparatedByString: @"\n"] mutableCopy] autorelease];
  NSString *prefix = [key stringByAppendingString: @"="];
  NSUInteger i;

  for (i = 0; i < [lines count]; i++)
    {
      if ([[lines objectAtIndex: i] hasPrefix: prefix])
        {
          [lines replaceObjectAtIndex: i withObject: [prefix stringByAppendingString: value]];
        }
    }
  return [lines componentsJoinedByString: @"\n"];
}

/* Writes the keyfile in place and runs the run loop until the theme says
   the settings changed, at most five seconds. The seconds it took, or -1. */
static NSTimeInterval
QuirkProbeWriteKeyfileAndWait(NSString *path, NSString *contents)
{
  NSDate *start = [NSDate date];
  NSDate *limit = [start dateByAddingTimeInterval: 5.0];

  QuirkProbeLiveSettingsHeard = NO;
  [contents writeToFile: path atomically: NO encoding: NSUTF8StringEncoding error: NULL];
  while (QuirkProbeLiveSettingsHeard == NO && [limit timeIntervalSinceNow] > 0.0)
    {
      [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
                               beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.05]];
    }
  return QuirkProbeLiveSettingsHeard ? -[start timeIntervalSinceNow] : -1.0;
}

static NSString *
QuirkProbeHex(NSColor *color)
{
  NSColor *rgb = [color colorUsingColorSpaceName: NSCalibratedRGBColorSpace];

  if (rgb == nil)
    {
      return @"?";
    }
  return [NSString stringWithFormat: @"#%02x%02x%02x",
           (int)lround ([rgb redComponent] * 255.0),
           (int)lround ([rgb greenComponent] * 255.0),
           (int)lround ([rgb blueComponent] * 255.0)];
}

/* A window, drawn now, sampled at (x, y) from the frame view's top left:
   the frame view paints the window's background. */
static NSString *
QuirkProbeSampleWindow(NSWindow *window, NSInteger x, NSInteger y)
{
  NSView *view = [[window contentView] superview];
  NSBitmapImageRep *rep;

  [window display];
  rep = [view bitmapImageRepForCachingDisplayInRect: [view bounds]];
  [view cacheDisplayInRect: [view bounds] toBitmapImageRep: rep];
  return QuirkProbeHex ([rep colorAtX: x y: y]);
}

@implementation QuirkProbe (LiveSettings)

- (void) checkLiveSettings
{
  NSString *configHome = [[[NSProcessInfo processInfo] environment] objectForKey: @"XDG_CONFIG_HOME"];
  NSString *path = [configHome stringByAppendingPathComponent: @"glib-2.0/settings/keyfile"];
  NSString *original = [NSString stringWithContentsOfFile: path encoding: NSUTF8StringEncoding error: NULL];
  NSString *changed;
  NSWindow *window;
  NSButton *before;
  NSTextView *text;
  CGFloat oldTextFont;
  NSButton *after;
  NSTimeInterval heard;
  NSString *lightWindow, *darkWindow, *lightColor, *darkColor, *backColor, *backWindow;
  CGFloat lightFont, largeFont, backFont, oldButtonFont, newButtonFont;
  CGFloat expected = 11.0 * 96.0 / 72.0;
  BOOL ok;

  if (original == nil
    || [[[[NSProcessInfo processInfo] environment] objectForKey: @"GSETTINGS_BACKEND"] isEqualToString: @"keyfile"] == NO)
    {
      [self skip: @"live-settings" detail: @"needs the probe's own keyfile GSettings (run-quirk-probe.sh)"];
      return;
    }
  [[NSNotificationCenter defaultCenter]
    addObserver: [QuirkProbeLiveSettingsListener class]
       selector: @selector(heard:)
           name: @"GnomeThemeDesktopSettingsDidChangeNotification"
         object: nil];

  window = [[NSWindow alloc] initWithContentRect: NSMakeRect (100, 100, 240, 120)
                                       styleMask: NSTitledWindowMask | NSClosableWindowMask
                                                  | NSMiniaturizableWindowMask | NSResizableWindowMask
                                         backing: NSBackingStoreBuffered
                                           defer: NO];
  [window setTitle: @"Live settings"];
  before = [[NSButton alloc] initWithFrame: NSMakeRect (20, 20, 120, 34)];
  [before setTitle: @"Before"];
  [[window contentView] addSubview: before];
  text = [[NSTextView alloc] initWithFrame: NSMakeRect (150, 20, 80, 34)];
  [text setString: @"Typed"];
  [[window contentView] addSubview: text];
  [window orderFront: nil];
  lightWindow = QuirkProbeSampleWindow (window, 200, 10);
  lightColor = QuirkProbeHex ([NSColor windowBackgroundColor]);
  lightFont = [[NSFont systemFontOfSize: 0] pointSize];

  /* Dark style and Large Text at 1.25, as GNOME Settings would set them. */
  changed = QuirkProbeKeyfileSetting (original, @"color-scheme", @"'prefer-dark'");
  changed = QuirkProbeKeyfileSetting (changed, @"text-scaling-factor", @"1.25");
  heard = QuirkProbeWriteKeyfileAndWait (path, changed);
  darkWindow = QuirkProbeSampleWindow (window, 200, 10);
  darkColor = QuirkProbeHex ([NSColor windowBackgroundColor]);
  largeFont = [[NSFont systemFontOfSize: 0] pointSize];
  oldButtonFont = [[before font] pointSize];
  oldTextFont = [[[text textStorage] attribute: NSFontAttributeName atIndex: 0 effectiveRange: NULL] pointSize];
  after = [[NSButton alloc] initWithFrame: NSMakeRect (20, 60, 120, 34)];
  [after setTitle: @"After"];
  newButtonFont = [[after font] pointSize];

  ok = heard >= 0.0
    && [darkColor isEqualToString: lightColor] == NO
    && [darkColor isEqualToString: @"#222226"]
    && [darkWindow isEqualToString: darkColor];
  [self liveSettingsResult: ok ident: @"live-settings-dark"
        detail: [NSString stringWithFormat:
         @"heard after %.2fs; window background %@ -> %@ (system colour %@ -> %@, want #222226)",
         heard, lightWindow, darkWindow, lightColor, darkColor]];

  ok = heard >= 0.0
    && fabs (lightFont - expected) < 0.01
    && fabs (largeFont - expected * 1.25) < 0.01
    && fabs (newButtonFont - expected * 1.25) < 0.01;
  [self liveSettingsResult: ok ident: @"live-settings-large-text"
        detail: [NSString stringWithFormat:
         @"system font %.3f -> %.3f (want %.3f); a button made after %.3f; made before: a button keeps %.3f, a text view's text %.3f",
         lightFont, largeFont, expected * 1.25, newButtonFont, oldButtonFont, oldTextFont]];

  /* And back. */
  heard = QuirkProbeWriteKeyfileAndWait (path, original);
  backWindow = QuirkProbeSampleWindow (window, 200, 10);
  backColor = QuirkProbeHex ([NSColor windowBackgroundColor]);
  backFont = [[NSFont systemFontOfSize: 0] pointSize];
  ok = heard >= 0.0
    && [backColor isEqualToString: lightColor]
    && [backWindow isEqualToString: lightWindow]
    && fabs (backFont - expected) < 0.01;
  [self liveSettingsResult: ok ident: @"live-settings-back"
        detail: [NSString stringWithFormat:
         @"heard after %.2fs; window %@ (was %@), system font %.3f (was %.3f)",
         heard, backWindow, lightWindow, backFont, lightFont]];

  [self checkLiveButtonLayout: window keyfile: path original: original];
  [[NSNotificationCenter defaultCenter] removeObserver: [QuirkProbeLiveSettingsListener class]];
  [after release];
  [text release];
  [before release];
  [window orderOut: nil];
}

/* With the header bar: a new button-layout lays the window buttons out
   again in an open window. */
- (void) checkLiveButtonLayout: (NSWindow *)window
                       keyfile: (NSString *)path
                      original: (NSString *)original
{
  NSView *frameView = [[window contentView] superview];
  NSButton *minimize;
  BOOL shownBefore, shownAfter, shownBack;
  NSTimeInterval heard;

  if ([frameView respondsToSelector: @selector(buttonNamed:)] == NO)
    {
      [self skip: @"live-settings-button-layout" detail: @"needs the header bar (-GSX11HandlesWindowDecorations NO)"];
      return;
    }
  minimize = [frameView performSelector: @selector(buttonNamed:) withObject: @"minimize"];
  shownBefore = minimize != nil && [minimize isHidden] == NO;
  heard = QuirkProbeWriteKeyfileAndWait (path, QuirkProbeKeyfileSetting (original, @"button-layout", @"'appmenu:close'"));
  shownAfter = minimize != nil && [minimize isHidden] == NO;
  QuirkProbeWriteKeyfileAndWait (path, original);
  shownBack = minimize != nil && [minimize isHidden] == NO;
  [self liveSettingsResult: (heard >= 0.0 && shownBefore && shownAfter == NO && shownBack)
                     ident: @"live-settings-button-layout"
                    detail: [NSString stringWithFormat:
     @"minimize button with appmenu:minimize,maximize,close %@, with appmenu:close %@, back %@",
     shownBefore ? @"shown" : @"hidden", shownAfter ? @"shown" : @"hidden", shownBack ? @"shown" : @"hidden"]];
}

- (void) liveSettingsResult: (BOOL)ok ident: (NSString *)ident detail: (NSString *)detail
{
  if (ok)
    {
      [self pass: ident detail: detail];
    }
  else
    {
      [self fail: ident detail: detail];
    }
}

@end
