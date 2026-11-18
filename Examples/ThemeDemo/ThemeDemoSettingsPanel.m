/* ThemeDemoSettingsPanel.m: the theme's settings, in a panel

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

#import "ThemeDemoSettingsPanel.h"

#import <ThemeSettingsKit/ThemeSettingsKit.h>
#import <ThemeSettingsUI/ThemeSettingsUI.h>

/* The defaults domain ThemeDemo's settings live in: its bundle
   identifier, else (an unpackaged build) its process name, as
   gnustep-base names the application domain. */
static NSString *
ThemeDemoDomain (void)
{
  NSString *domain = [[NSBundle mainBundle] bundleIdentifier];

  if ([domain length] == 0)
    {
      domain = [[NSProcessInfo processInfo] processName];
    }
  return domain;
}

@interface ThemeDemoSettingsPanel (Private)
- (void) buildPanel;
- (BOOL) targetApplication;
- (BOOL) confirmDiscard;
- (void) toggleAllApplications: (id)sender;
@end

@implementation ThemeDemoSettingsPanel

- (id) init
{
  if ((self = [super init]) != nil)
    {
      GTSDefaultsDomainStore *store;
      GTSThemeCatalog *catalog;

      store = AUTORELEASE ([[GTSDefaultsDomainStore alloc]
	initWithHostDefaults: [NSUserDefaults standardUserDefaults]]);
      catalog = AUTORELEASE ([[GTSThemeCatalog alloc] init]);
      _model = [[GTSEditorModel alloc] initWithStore: store catalog: catalog];
      [_model setHostDomain: ThemeDemoDomain ()];
      /* If the target can't be read, the editor says "Unknown": shown as
	 it is, not hidden. */
      [self targetApplication];
      _editor = [[GTSThemeSettingsEditor alloc] initWithModel: _model];
      [_editor setDelegate: self];
      _confirmAnswer = -1;
      [self buildPanel];
    }
  return self;
}

- (void) dealloc
{
  [_editor setDelegate: nil];
  RELEASE (_editor);
  RELEASE (_model);
  RELEASE (_panel);
  [super dealloc];
}

- (NSPanel *) panel
{
  return _panel;
}

- (void) show
{
  [_panel makeKeyAndOrderFront: self];
}

- (BOOL) performScriptedAction: (NSString *)action
{
  NSArray *words = [action componentsSeparatedByString: @" "];
  NSString *verb = [words count] > 0 ? [words objectAtIndex: 0] : @"";
  NSString *arg = [words count] > 1 ? [words objectAtIndex: 1] : @"";

  if ([verb isEqualToString: @"all-applications"])
    {
      BOOL on = [arg isEqualToString: @"on"];

      if ((on && [_allApplications state] == NSOnState)
	|| (!on && [_allApplications state] == NSOffState))
	{
	  return YES;
	}
      [_allApplications setState: on ? NSOnState : NSOffState];
      [self toggleAllApplications: _allApplications];
      /* Declined, the switch went back. */
      return (on == ([_allApplications state] == NSOnState));
    }
  if ([verb isEqualToString: @"wait-file"])
    {
      NSDate *limit = [NSDate dateWithTimeIntervalSinceNow: 20];
      NSFileManager *fm = [NSFileManager defaultManager];

      while (![fm fileExistsAtPath: arg]
	&& [limit timeIntervalSinceNow] > 0)
	{
	  [[NSRunLoop currentRunLoop] runUntilDate:
	    [NSDate dateWithTimeIntervalSinceNow: 0.05]];
	}
      return [fm fileExistsAtPath: arg];
    }
  if ([verb isEqualToString: @"confirm"])
    {
      _confirmAnswer = [arg isEqualToString: @"yes"] ? 1 : 0;
      return YES;
    }
  return [_editor performScriptedAction: action];
}

/* GTSThemeSettingsEditorDelegate.  The outcome, never the message text,
   says what happened; the editor itself shows it and offers Reload. */
- (void) themeSettingsEditorDidApply: (GTSThemeSettingsEditor *)editor
{
}

- (void) themeSettingsEditor: (GTSThemeSettingsEditor *)editor
  didFinishApplyWithOutcome: (GTSApplyOutcome *)outcome
{
  if ([[NSUserDefaults standardUserDefaults]
	boolForKey: @"ThemeDemoSettingsLog"])
    {
      fprintf (stderr, "ThemeDemo-settings apply kind=%d wrote=%d"
	" reload=%d target=%s\n", (int)[outcome kind], (int)[outcome didWrite],
	(int)[outcome needsReload], [[_model targetTitle] UTF8String]);
    }
}

@end

@implementation ThemeDemoSettingsPanel (Private)

- (void) buildPanel
{
  NSView *content;
  NSView *editorView = [_editor view];
  NSRect frame = NSMakeRect (0, 0, 680, 600);
  CGFloat top = NSHeight (frame) - 12;

  _panel = [[NSPanel alloc] initWithContentRect: frame
				      styleMask: (NSTitledWindowMask
						  | NSClosableWindowMask
						  | NSResizableWindowMask)
					backing: NSBackingStoreBuffered
					  defer: YES];
  [_panel setTitle: @"Theme Settings"];
  [_panel setReleasedWhenClosed: NO];
  [_panel setMinSize: NSMakeSize (520, 360)];
  content = [_panel contentView];

  /* The switch to all applications; the editor says what it applies
     to. */
  _allApplications = AUTORELEASE ([[NSButton alloc]
    initWithFrame: NSMakeRect (12, top - 22, NSWidth (frame) - 24, 22)]);
  [_allApplications setButtonType: NSSwitchButton];
  [_allApplications setTitle: @"Change the settings of all applications"];
  [_allApplications setTarget: self];
  [_allApplications setAction: @selector(toggleAllApplications:)];
  [_allApplications setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];
  [content addSubview: _allApplications];

  [editorView setFrame: NSMakeRect (0, 0, NSWidth (frame), top - 30)];
  [editorView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
  [content addSubview: editorView];
  [_panel center];
}

- (BOOL) targetApplication
{
  NSString *domain = ThemeDemoDomain ();

  return [_model setTargetApplicationDomain: domain
				displayName: @"This application"
				       info: [[NSBundle mainBundle]
					       infoDictionary]];
}

/* Switching what the settings apply to drops what is staged and not
   applied: the user says first whether that's all right. */
- (BOOL) confirmDiscard
{
  int answer;

  if (![_model hasChanges])
    {
      return YES;
    }
  if (_confirmAnswer >= 0)
    {
      answer = _confirmAnswer;
      _confirmAnswer = -1;
      return answer == 1;
    }
  return NSRunAlertPanel (@"Discard your changes?",
    @"You have changes that aren't applied yet. Switching what the"
    @" settings apply to discards them.",
    @"Discard", @"Cancel", nil) == NSAlertDefaultReturn;
}

- (void) toggleAllApplications: (id)sender
{
  BOOL global = ([_allApplications state] == NSOnState);

  if (![self confirmDiscard])
    {
      [_allApplications setState: global ? NSOffState : NSOnState];
      return;
    }
  if (global)
    {
      [_model setTargetGlobal];
    }
  else
    {
      [self targetApplication];
    }
  [_editor reloadFromModel];
}

@end
