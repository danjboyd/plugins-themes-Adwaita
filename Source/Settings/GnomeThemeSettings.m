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

#import "GnomeThemeSettings.h"

#import <AppKit/AppKit.h>
#import <gio/gio.h>

static NSString *GnomeThemeDefaultInterfaceFontName = @"Cantarell";
static NSString *GnomeThemeDefaultMonospaceFontName = @"Monospace";
static CGFloat GnomeThemeDefaultInterfaceFontSize = 11.0;
static CGFloat GnomeThemeDefaultMonospaceFontSize = 11.0;
static CGFloat GnomeThemeDefaultFontScale = (96.0 / 72.0);
/* GNUstep's default NSFontSize, which Gorm and nib layouts were made at. */
static CGFloat GnomeThemeCompactInterfaceFontSize = 12.0;

static BOOL
GnomeThemeWantsCompactMetrics(void)
{
  NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
  NSString *choice = [[NSUserDefaults standardUserDefaults] stringForKey: @"GnomeThemeMetrics"];
  id declared = [info objectForKey: @"GnomeThemeMetrics"];
  NSEnumerator *enumerator;
  NSString *key;

  /* The user's default, then the app's own choice in its Info.plist (an
     app laid out in Gorm for GNOME's metrics declares "gnome"), then the
     main nib test. */
  if (choice == nil && [declared isKindOfClass: [NSString class]])
    {
      choice = declared;
    }
  if (choice != nil && [choice caseInsensitiveCompare: @"compact"] == NSOrderedSame)
    {
      return YES;
    }
  if (choice != nil && [choice caseInsensitiveCompare: @"gnome"] == NSOrderedSame)
    {
      return NO;
    }
  enumerator = [[NSArray arrayWithObjects: @"NSMainNibFile", @"NSMainStoryboardFile",
                                           @"GSMainMarkupFile", nil] objectEnumerator];
  while ((key = [enumerator nextObject]) != nil)
    {
      id value = [info objectForKey: key];

      if ([value isKindOfClass: [NSString class]] && [value length] > 0)
        {
          return YES;
        }
    }
  return NO;
}

static CGFloat
GnomeThemeResolvedFontScale(void)
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  id value = [defaults objectForKey: @"GnomeFontScale"];
  CGFloat scale = GnomeThemeDefaultFontScale;
  CGFloat overrideScale = 1.0;

  if (value != nil)
    {
      overrideScale = [defaults floatForKey: @"GnomeFontScale"];
    }

  if (overrideScale < 0.8 || overrideScale > 2.0)
    {
      overrideScale = 1.0;
    }

  return (scale * overrideScale);
}

static GSettings *
GnomeThemeCreateDesktopSettings(const char *schemaID, GSettingsSchema **schemaOut)
{
  GSettingsSchemaSource *source = g_settings_schema_source_get_default ();
  GSettingsSchema *schema = NULL;
  GSettings *settings = NULL;

  if (source != NULL)
    {
      schema = g_settings_schema_source_lookup (source, schemaID, TRUE);
    }

  if (schema != NULL)
    {
      settings = g_settings_new_full (schema, NULL, NULL);
    }

  if (schemaOut != NULL)
    {
      *schemaOut = schema;
    }
  else if (schema != NULL)
    {
      g_settings_schema_unref (schema);
    }

  return settings;
}

static void
GnomeThemeParseFontSpec(NSString *spec, NSString **nameOut, CGFloat *sizeOut)
{
  NSString *name = nil;
  CGFloat size = 0.0;

  if ([spec length] > 0)
    {
      NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
      NSRange lastSpace = [spec rangeOfCharacterFromSet: whitespace
                                                options: NSBackwardsSearch];
      if (lastSpace.location != NSNotFound)
        {
          NSString *maybeName = [[spec substringToIndex: lastSpace.location]
            stringByTrimmingCharactersInSet: whitespace];
          NSString *maybeSize = [[spec substringFromIndex: lastSpace.location]
            stringByTrimmingCharactersInSet: whitespace];

          if ([maybeName length] > 0)
            {
              name = maybeName;
            }

          if ([maybeSize length] > 0)
            {
              size = [maybeSize floatValue];
            }
        }
      else
        {
          name = spec;
        }
    }

  if (nameOut != NULL)
    {
      *nameOut = name;
    }
  if (sizeOut != NULL)
    {
      *sizeOut = size;
    }
}

static NSFont *
GnomeThemeResolveFont(NSString *preferredName,
                      CGFloat preferredSize,
                      NSArray *fallbackNames,
                      BOOL fixedPitch)
{
  NSFont *font = nil;
  NSFontManager *fontManager = [NSFontManager sharedFontManager];
  NSEnumerator *enumerator = [fallbackNames objectEnumerator];
  NSString *candidate = nil;
  CGFloat size = preferredSize > 0.0 ? preferredSize : GnomeThemeDefaultInterfaceFontSize;
  NSFontTraitMask traits = fixedPitch ? NSFixedPitchFontMask : 0;

  if ([preferredName length] > 0)
    {
      font = [NSFont fontWithName: preferredName size: size];
      if (font == nil && fontManager != nil)
        {
          font = [fontManager fontWithFamily: preferredName
                                      traits: traits
                                      weight: 5
                                        size: size];
        }
    }

  while (font == nil && (candidate = [enumerator nextObject]) != nil)
    {
      font = [NSFont fontWithName: candidate size: size];
      if (font == nil && fontManager != nil)
        {
          font = [fontManager fontWithFamily: candidate
                                      traits: traits
                                      weight: 5
                                        size: size];
        }
    }

  if (font == nil && fixedPitch)
    {
      font = [NSFont userFixedPitchFontOfSize: size];
    }
  else if (font == nil)
    {
      font = [NSFont systemFontOfSize: size];
    }

  return font;
}

@interface GnomeThemeSettings (Private)
- (void) reloadWindowManagerPreferences;
@end

@implementation GnomeThemeSettings

- (id) init
{
  self = [super init];
  if (self != nil)
    {
      [self reload];
    }
  return self;
}

- (void) dealloc
{
  RELEASE (_interfaceFontName);
  RELEASE (_monospaceFontName);
  RELEASE (_gtkThemeName);
  RELEASE (_buttonLayout);
  RELEASE (_titlebarDoubleClickAction);
  RELEASE (_titlebarMiddleClickAction);
  RELEASE (_titlebarRightClickAction);
  [super dealloc];
}

- (void) reload
{
  GSettingsSchema *schema = NULL;
  GSettings *settings = GnomeThemeCreateDesktopSettings ("org.gnome.desktop.interface", &schema);
  NSString *fontName = nil;
  NSString *monoName = nil;
  NSString *fontSpec = nil;
  NSString *monoSpec = nil;
  CGFloat fontSize = 0.0;
  CGFloat monoSize = 0.0;
  GnomeThemeColorScheme colorScheme = GnomeThemeColorSchemeDefault;
  BOOL highContrast = NO;
  BOOL overlayScrolling = YES;
  NSString *gtkThemeName = @"Adwaita";
  CGFloat fontScale = GnomeThemeResolvedFontScale ();

  if (settings != NULL && schema != NULL)
    {
      if (g_settings_schema_has_key (schema, "font-name"))
        {
          gchar *value = g_settings_get_string (settings, "font-name");
          if (value != NULL)
            {
              fontSpec = [NSString stringWithUTF8String: value];
              g_free (value);
            }
        }

      if (g_settings_schema_has_key (schema, "monospace-font-name"))
        {
          gchar *value = g_settings_get_string (settings, "monospace-font-name");
          if (value != NULL)
            {
              monoSpec = [NSString stringWithUTF8String: value];
              g_free (value);
            }
        }

      if (g_settings_schema_has_key (schema, "gtk-theme"))
        {
          gchar *value = g_settings_get_string (settings, "gtk-theme");
          if (value != NULL)
            {
              gtkThemeName = [NSString stringWithUTF8String: value];
              g_free (value);
            }
        }

      if (g_settings_schema_has_key (schema, "overlay-scrolling"))
        {
          overlayScrolling = g_settings_get_boolean (settings, "overlay-scrolling") ? YES : NO;
        }

      if (g_settings_schema_has_key (schema, "color-scheme"))
        {
          gchar *value = g_settings_get_string (settings, "color-scheme");
          if (value != NULL)
            {
              NSString *scheme = [NSString stringWithUTF8String: value];
              if ([scheme isEqualToString: @"prefer-dark"])
                {
                  colorScheme = GnomeThemeColorSchemePreferDark;
                }
              else if ([scheme isEqualToString: @"prefer-light"])
                {
                  colorScheme = GnomeThemeColorSchemePreferLight;
                }
              g_free (value);
            }
        }

      g_object_unref (settings);
      g_settings_schema_unref (schema);
    }

  GnomeThemeParseFontSpec (fontSpec, &fontName, &fontSize);
  GnomeThemeParseFontSpec (monoSpec, &monoName, &monoSize);

  if ([fontName length] == 0)
    {
      fontName = GnomeThemeDefaultInterfaceFontName;
    }
  if (fontSize <= 0.0)
    {
      fontSize = GnomeThemeDefaultInterfaceFontSize;
    }

  if ([monoName length] == 0)
    {
      monoName = GnomeThemeDefaultMonospaceFontName;
    }
  if (monoSize <= 0.0)
    {
      monoSize = GnomeThemeDefaultMonospaceFontSize;
    }

  fontSize *= fontScale;
  monoSize *= fontScale;

  _compactMetrics = GnomeThemeWantsCompactMetrics ();
  if (_compactMetrics)
    {
      /* GNUstep's size, still following GnomeFontScale; the monospace font
         keeps its size relative to the interface font. */
      CGFloat compact = GnomeThemeCompactInterfaceFontSize * (fontScale / GnomeThemeDefaultFontScale);

      monoSize *= compact / fontSize;
      fontSize = compact;
    }

  /* Current GNOME: an accessibility setting, with the light or dark
     palette. Without it, GNOME 3's themes: HighContrast (dark on light)
     and HighContrastInverse (light on dark). */
  {
    GSettingsSchema *a11ySchema = NULL;
    GSettings *a11y = GnomeThemeCreateDesktopSettings ("org.gnome.desktop.a11y.interface", &a11ySchema);

    if (a11y != NULL && a11ySchema != NULL && g_settings_schema_has_key (a11ySchema, "high-contrast"))
      {
        highContrast = g_settings_get_boolean (a11y, "high-contrast") ? YES : NO;
      }
    if (a11y != NULL)
      {
        g_object_unref (a11y);
      }
    if (a11ySchema != NULL)
      {
        g_settings_schema_unref (a11ySchema);
      }
    if ([gtkThemeName rangeOfString: @"HighContrast"
                            options: NSCaseInsensitiveSearch].location != NSNotFound)
      {
        highContrast = YES;
        if ([gtkThemeName rangeOfString: @"Inverse" options: NSCaseInsensitiveSearch].location != NSNotFound
          && colorScheme == GnomeThemeColorSchemeDefault)
          {
            colorScheme = GnomeThemeColorSchemePreferDark;
          }
      }
  }

  if (colorScheme == GnomeThemeColorSchemeDefault)
    {
      if ([gtkThemeName hasSuffix: @"-dark"] || [gtkThemeName hasSuffix: @"-Dark"])
        {
          colorScheme = GnomeThemeColorSchemePreferDark;
        }
    }

  ASSIGNCOPY (_interfaceFontName, fontName);
  _interfaceFontSize = fontSize;
  ASSIGNCOPY (_monospaceFontName, monoName);
  _monospaceFontSize = monoSize;
  ASSIGNCOPY (_gtkThemeName, gtkThemeName);
  _colorScheme = colorScheme;
  _highContrast = highContrast;
  _overlayScrolling = overlayScrolling;

  [self reloadWindowManagerPreferences];
}

/* The window buttons' order and the title bar double-click action, which
   GTK takes from the window manager's preferences for its header bars. */
- (void) reloadWindowManagerPreferences
{
  GSettingsSchema *schema = NULL;
  GSettings *settings = GnomeThemeCreateDesktopSettings ("org.gnome.desktop.wm.preferences", &schema);
  NSString *buttonLayout = nil;
  NSString *doubleClick = nil;
  NSString *middleClick = nil;
  NSString *rightClick = nil;

  if (settings != NULL && schema != NULL)
    {
      if (g_settings_schema_has_key (schema, "button-layout"))
        {
          gchar *value = g_settings_get_string (settings, "button-layout");
          if (value != NULL)
            {
              buttonLayout = [NSString stringWithUTF8String: value];
              g_free (value);
            }
        }
      if (g_settings_schema_has_key (schema, "action-double-click-titlebar"))
        {
          gchar *value = g_settings_get_string (settings, "action-double-click-titlebar");
          if (value != NULL)
            {
              doubleClick = [NSString stringWithUTF8String: value];
              g_free (value);
            }
        }
      if (g_settings_schema_has_key (schema, "action-middle-click-titlebar"))
        {
          gchar *value = g_settings_get_string (settings, "action-middle-click-titlebar");
          if (value != NULL)
            {
              middleClick = [NSString stringWithUTF8String: value];
              g_free (value);
            }
        }
      if (g_settings_schema_has_key (schema, "action-right-click-titlebar"))
        {
          gchar *value = g_settings_get_string (settings, "action-right-click-titlebar");
          if (value != NULL)
            {
              rightClick = [NSString stringWithUTF8String: value];
              g_free (value);
            }
        }
      g_object_unref (settings);
    }
  if (schema != NULL)
    {
      g_settings_schema_unref (schema);
    }

  /* GNOME's defaults. */
  ASSIGNCOPY (_buttonLayout, [buttonLayout length] > 0 ? buttonLayout : @"appmenu:close");
  ASSIGNCOPY (_titlebarDoubleClickAction, [doubleClick length] > 0 ? doubleClick : @"toggle-maximize");
  ASSIGNCOPY (_titlebarMiddleClickAction, [middleClick length] > 0 ? middleClick : @"none");
  ASSIGNCOPY (_titlebarRightClickAction, [rightClick length] > 0 ? rightClick : @"menu");
}

- (NSString *) buttonLayout
{
  return _buttonLayout;
}

- (NSString *) titlebarDoubleClickAction
{
  return _titlebarDoubleClickAction;
}

- (NSString *) titlebarMiddleClickAction
{
  return _titlebarMiddleClickAction;
}

- (NSString *) titlebarRightClickAction
{
  return _titlebarRightClickAction;
}

- (NSString *) interfaceFontName
{
  return _interfaceFontName;
}

- (CGFloat) interfaceFontSize
{
  return _interfaceFontSize;
}

- (BOOL) compactMetrics
{
  return _compactMetrics;
}

- (NSString *) monospaceFontName
{
  return _monospaceFontName;
}

- (CGFloat) monospaceFontSize
{
  return _monospaceFontSize;
}

- (NSString *) gtkThemeName
{
  return _gtkThemeName;
}

- (BOOL) prefersDarkAppearance
{
  return (_colorScheme == GnomeThemeColorSchemePreferDark);
}

- (BOOL) highContrastEnabled
{
  return _highContrast;
}

- (BOOL) overlayScrollingEnabled
{
  return _overlayScrolling;
}

- (NSFont *) interfaceFont
{
  NSArray *fallbacks = [NSArray arrayWithObjects:
    @"Cantarell",
    @"Noto Sans",
    @"DejaVu Sans",
    @"Liberation Sans",
    nil];

  return GnomeThemeResolveFont (_interfaceFontName,
                                _interfaceFontSize,
                                fallbacks,
                                NO);
}

/* The bold face of the interface font, or nil when its family has none (the
   theme then leaves GNUstep's own bold font in place). Cantarell's bold face
   comes from a variable font and is named "Cantarell_700wght", so it is found
   through the font manager rather than by name. */
- (NSFont *) boldInterfaceFont
{
  NSFontManager *fontManager = [NSFontManager sharedFontManager];
  NSFont *font = [self interfaceFont];
  NSFont *boldFont = nil;

  if (font == nil || fontManager == nil)
    {
      return nil;
    }
  boldFont = [fontManager convertFont: font toHaveTrait: NSBoldFontMask];
  if (boldFont == nil || ([fontManager traitsOfFont: boldFont] & NSBoldFontMask) == 0)
    {
      return nil;
    }
  return boldFont;
}

- (NSFont *) menuFont
{
  NSArray *fallbacks = [NSArray arrayWithObjects:
    @"Cantarell",
    @"Noto Sans",
    @"DejaVu Sans",
    @"Liberation Sans",
    nil];

  return GnomeThemeResolveFont (_interfaceFontName,
                                _interfaceFontSize + 0.75,
                                fallbacks,
                                NO);
}

- (NSFont *) menuBarFont
{
  NSArray *fallbacks = [NSArray arrayWithObjects:
    @"Cantarell",
    @"Noto Sans",
    @"DejaVu Sans",
    @"Liberation Sans",
    nil];

  return GnomeThemeResolveFont (_interfaceFontName,
                                _interfaceFontSize + 1.0,
                                fallbacks,
                                NO);
}

- (NSFont *) fixedPitchFont
{
  NSArray *fallbacks = [NSArray arrayWithObjects:
    @"Cantarell Mono",
    @"Noto Sans Mono",
    @"DejaVu Sans Mono",
    @"Liberation Mono",
    @"Courier",
    nil];

  return GnomeThemeResolveFont (_monospaceFontName,
                                _monospaceFontSize,
                                fallbacks,
                                YES);
}

@end
