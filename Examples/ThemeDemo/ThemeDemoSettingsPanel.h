/* ThemeDemoSettingsPanel.h: the theme's settings, in a panel

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

#import <AppKit/AppKit.h>

@class GTSEditorModel, GTSThemeSettingsEditor;

/* A panel with gnustep-themes' settings editor (ThemeSettingsUI), for the
   theme ThemeDemo runs with: by default ThemeDemo's own settings, or, with
   the switch at the top, those of all applications. Built only when the
   ThemeSettings libraries are there (GNUmakefile). */
@interface ThemeDemoSettingsPanel : NSObject
{
  NSPanel *_panel;
  NSButton *_allApplications;
  GTSEditorModel *_model;
  GTSThemeSettingsEditor *_editor;
  int _confirmAnswer;   /* scripted runs: -1 ask, 0 no, 1 yes */
}

- (NSPanel *) panel;
- (void) show;

/* For scripted checks and screenshots (-ThemeDemoSettingsScript): the
   editor's own actions ("choose <settingId> <value>", "reset <settingId>",
   "apply", ...) and the panel's: "all-applications on|off",
   "confirm yes|no" (how the next "discard staged changes?" question is
   answered, instead of asking) and "wait-file <path>" (waits up to 20 s
   for the file, so a check can change the defaults from outside at a
   known point). Returns NO if it couldn't be done. */
- (BOOL) performScriptedAction: (NSString *)action;
@end
