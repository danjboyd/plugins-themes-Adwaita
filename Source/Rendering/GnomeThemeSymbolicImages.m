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

/* Template images tinted with the foreground colour, as GTK tints symbolic
   icons: an app ships one monochrome icon set and it reads right in light,
   dark and high contrast, in the header bar's backdrop state, on a
   suggested (blue) button and in menus. Only the image's alpha is used.

   An image is a template when -[NSImage isTemplate] says so (libs-gui
   after 0.32), or by its name: Cocoa's "…Template" or GNOME's
   "…-symbolic", for libs-gui 0.32, which has no -setTemplate:. Buttons,
   toolbar items and menu items all draw their image through
   -[NSButtonCell drawImage:withFrame:inView:]. */

#import "../GnomeTheme.h"

#import <AppKit/AppKit.h>
#import <objc/runtime.h>

@interface NSImage (GnomeThemeSymbolicImages)
- (BOOL) isTemplate;
@end

static char GnomeThemeTintedImagesKey;

BOOL
GnomeThemeImageIsTemplate(NSImage *image)
{
  NSString *name;

  if (image == nil)
    {
      return NO;
    }
  if ([image respondsToSelector: @selector(isTemplate)] && [image isTemplate])
    {
      return YES;
    }
  name = [image name];
  return [name hasSuffix: @"Template"] || [name hasSuffix: @"-symbolic"];
}

/* The image's shape in `color`, kept with the image for each colour it's
   drawn in (a few: the states of the palette in use). */
NSImage *
GnomeThemeTintedImage(NSImage *image, NSColor *color)
{
  NSMutableDictionary *tinted = objc_getAssociatedObject (image, &GnomeThemeTintedImagesKey);
  NSColor *rgb = [color colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
  NSString *key;
  NSImage *result;
  NSSize size = [image size];
  NSRect rect = NSMakeRect (0.0, 0.0, size.width, size.height);

  if (rgb == nil || size.width <= 0.0 || size.height <= 0.0)
    {
      return image;
    }
  key = [NSString stringWithFormat: @"%.4f %.4f %.4f %.4f", [rgb redComponent], [rgb greenComponent],
                  [rgb blueComponent], [rgb alphaComponent]];
  result = [tinted objectForKey: key];
  if (result != nil)
    {
      return result;
    }
  if (tinted == nil)
    {
      tinted = [NSMutableDictionary dictionary];
      objc_setAssociatedObject (image, &GnomeThemeTintedImagesKey, tinted, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
  result = AUTORELEASE ([[NSImage alloc] initWithSize: size]);
  [result lockFocus];
  [image drawInRect: rect fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1.0];
  [rgb set];
  NSRectFillUsingOperation (rect, NSCompositeSourceIn);
  [result unlockFocus];
  [tinted setObject: result forKey: key];
  return result;
}

/* Whether the control is in a toolbar shown in the header bar. */
static BOOL
GnomeThemeViewIsInHeaderBarToolbar(NSView *controlView)
{
  NSView *view;

  for (view = controlView; view != nil; view = [view superview])
    {
      if ([view respondsToSelector: @selector(toolbar)] && [view isKindOfClass: [NSControl class]] == NO)
        {
          NSToolbar *toolbar = [(id)view toolbar];

          return [toolbar isKindOfClass: [NSToolbar class]] && GnomeThemeToolbarInHeaderBar (toolbar);
        }
    }
  return NO;
}

/* A template image's colour in a control: the header bar's for one in a
   toolbar in the bar (dimmed in the backdrop state), the disabled text
   colour when `dimmed`, else `text`. For buttons and segmented controls. */
NSColor *
GnomeThemeTemplateImageColorInView(NSView *controlView, BOOL dimmed, NSColor *text)
{
  if (GnomeThemeViewIsInHeaderBarToolbar (controlView))
    {
      NSColor *color = GnomeThemeHeaderBarTextColor ([controlView window]);

      return dimmed ? [color colorWithAlphaComponent: [color alphaComponent] * 0.5] : color;
    }
  if (dimmed)
    {
      return [NSColor disabledControlTextColor];
    }
  return text != nil ? text : [NSColor controlTextColor];
}

@implementation GnomeTheme (SymbolicImages)

/* The colour the cell's title is drawn in: the header bar's for its
   toolbar items (dimmed in the backdrop state), white on a suggested
   button, the menu's text colour in menus. */
static NSColor *
GnomeThemeTemplateImageColor(NSButtonCell *cell, NSView *controlView)
{
  BOOL enabled = [cell isEnabled];
  /* A cell that dims its image itself (libs-gui draws it at half
     opacity) gets the enabled colour. */
  BOOL dimmed = enabled == NO && [cell imageDimsWhenDisabled] == NO;
  NSString *keyEquivalent = [cell keyEquivalent];

  if ([cell isKindOfClass: [NSMenuItemCell class]])
    {
      if (dimmed)
        {
          return [NSColor disabledControlTextColor];
        }
      /* Only the menu bar's accent pill has white content; a vertical
         menu's hovered row is neutral (#67). */
      return ([cell isHighlighted] && [[(NSMenuItemCell *)cell menuView] isHorizontal])
        ? [NSColor selectedMenuItemTextColor] : [NSColor controlTextColor];
    }
  if (dimmed || GnomeThemeViewIsInHeaderBarToolbar (controlView))
    {
      return GnomeThemeTemplateImageColorInView (controlView, dimmed, nil);
    }
  if (enabled && ([keyEquivalent isEqualToString: @"\r"] || [keyEquivalent isEqualToString: @"\n"]
                  || (controlView != nil && [[controlView window] defaultButtonCell] == cell)))
    {
      return [NSColor selectedControlTextColor];
    }
  return [NSColor controlTextColor];
}

- (void) _overrideNSButtonCellMethod_drawImage: (NSImage *)image
                                     withFrame: (NSRect)frame
                                        inView: (NSView *)controlView
{
  typedef void (*DrawImageIMP)(id, SEL, NSImage *, NSRect, NSView *);
  DrawImageIMP originalIMP = (DrawImageIMP)GnomeThemeOriginalMethod (_cmd, self, [NSButtonCell class]);

  if (GnomeThemeImageIsTemplate (image))
    {
      image = GnomeThemeTintedImage (image, GnomeThemeTemplateImageColor ((NSButtonCell *)self, controlView));
    }
  if (originalIMP != NULL)
    {
      originalIMP (self, _cmd, image, frame, controlView);
    }
}

@end
