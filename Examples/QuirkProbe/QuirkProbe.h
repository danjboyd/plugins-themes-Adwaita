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

#import <AppKit/AppKit.h>

/* Regression checks for theme bugs found by apps (first by
   OneDriveServiceManager). Each check renders controls offscreen and measures
   the result, so it doesn't depend on reference screenshots. Results go to
   stdout as PASS/FAIL/KNOWN/SKIP lines; the exit status is the number of
   failures. Run it through Tests/Scripts/run-quirk-probe.sh. */
@interface QuirkProbe : NSObject <NSToolbarDelegate>
{
  NSString *_outputDirectory;
  NSMutableArray *_windows;
  NSWindow *_controlsWindow;
  NSWindow *_toolbarWindow;
  NSWindow *_lateWindow;
  NSMutableArray *_sizedButtons;
  NSButton *_toolbarViewButton;
  NSTextField *_wrappingLabel;
  NSTextField *_newlineLabel;
  NSTextField *_pathLabel;
  NSTextField *_truncatedPathLabel;
  NSString *_alertText;
  NSUInteger _passed;
  NSUInteger _failed;
  NSUInteger _known;
  NSUInteger _skipped;
}
@end
