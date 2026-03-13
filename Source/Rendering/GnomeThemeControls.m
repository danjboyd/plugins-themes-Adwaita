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

#import "../GnomeTheme.h"
#import "../Settings/GnomeThemeMetrics.h"
#import "../Settings/GnomeThemeSettings.h"

#import <AppKit/AppKit.h>
#import <AppKit/NSGraphics.h>
#import <GNUstepGUI/GSTheme.h>
#import <math.h>

@interface NSComboBoxCell (GnomeThemePrivate)
- (void) _didClickWithinButton: (id)sender;
- (void) _performClickWithFrame: (NSRect)cellFrame
                         inView: (NSView *)controlView;
@end

@interface NSPopUpButtonCell (GnomeThemePrivate)
- (NSImage *) _currentArrowImage;
@end

@interface NSTextFieldCell (GnomeThemePrivateTextDrawing)
- (BOOL) _inEditing;
- (NSAttributedString *) _drawAttributedString;
- (void) _drawEditorWithFrame: (NSRect)cellFrame
                       inView: (NSView *)controlView;
- (BOOL) _shouldShortenStringForRect: (NSRect)titleRect
                                size: (NSSize)titleSize
                              length: (NSUInteger)length;
- (NSAttributedString *) _resizeAttributedString: (NSAttributedString *)attrstring
                                         forRect: (NSRect)titleRect;
@end

static NSRect GnomeThemeCenteredRect(NSRect frame, CGFloat width, CGFloat height);

static inline GnomeTheme *
GnomeThemeActiveTheme(void)
{
  GSTheme *theme = [GSTheme theme];

  if ([theme isKindOfClass: [GnomeTheme class]] == NO)
    {
      return nil;
    }

  return (GnomeTheme *)theme;
}

static inline BOOL
GnomeThemeStateIsDisabled(GSThemeControlState state)
{
  return (state == GSThemeDisabledState);
}

static inline BOOL
GnomeThemeStateIsFocused(GSThemeControlState state)
{
  return (state == GSThemeFirstResponderState
    || state == GSThemeHighlightedFirstResponderState
    || state == GSThemeSelectedFirstResponderState);
}

static inline BOOL
GnomeThemeStateIsHighlighted(GSThemeControlState state)
{
  return (state == GSThemeHighlightedState
    || state == GSThemeHighlightedFirstResponderState);
}

static inline BOOL
GnomeThemeStateIsSelected(GSThemeControlState state)
{
  return (state == GSThemeSelectedState
    || state == GSThemeSelectedFirstResponderState);
}

static NSColor *
GnomeThemeColor(GnomeTheme *theme, NSString *key, NSColor *fallback)
{
  NSColor *color = nil;

  if (theme != nil)
    {
      color = [theme colorNamed: key state: GSThemeNormalState];
    }

  return (color != nil) ? color : fallback;
}

static NSColor *
GnomeThemeBlend(NSColor *fromColor, NSColor *toColor, CGFloat fraction)
{
  NSColor *result = nil;

  if (fromColor == nil)
    {
      return toColor;
    }
  if (toColor == nil)
    {
      return fromColor;
    }

  result = [fromColor blendedColorWithFraction: fraction ofColor: toColor];
  return (result != nil) ? result : fromColor;
}

static NSBezierPath *
GnomeThemeRoundedPath(NSRect rect, CGFloat radius)
{
  CGFloat clampedRadius = MIN (radius, MIN (rect.size.width, rect.size.height) / 2.0);

  if (clampedRadius <= 0.0)
    {
      return [NSBezierPath bezierPathWithRect: rect];
    }

  return [NSBezierPath bezierPathWithRoundedRect: rect
                                         xRadius: clampedRadius
                                         yRadius: clampedRadius];
}

static NSBezierPath *
GnomeThemeSegmentedControlPath(NSRect rect,
                               CGFloat radius,
                               BOOL roundedLeft,
                               BOOL roundedRight)
{
  CGFloat clampedRadius = MIN (radius, MIN (rect.size.width, rect.size.height) / 2.0);
  CGFloat minX = NSMinX (rect);
  CGFloat maxX = NSMaxX (rect);
  CGFloat minY = NSMinY (rect);
  CGFloat maxY = NSMaxY (rect);
  NSBezierPath *path = nil;

  if (clampedRadius <= 0.0 || (roundedLeft == NO && roundedRight == NO))
    {
      return [NSBezierPath bezierPathWithRect: rect];
    }

  if (roundedLeft && roundedRight)
    {
      return GnomeThemeRoundedPath (rect, clampedRadius);
    }

  path = [NSBezierPath bezierPath];
  [path moveToPoint: NSMakePoint (minX + (roundedLeft ? clampedRadius : 0.0), minY)];
  [path lineToPoint: NSMakePoint (maxX - (roundedRight ? clampedRadius : 0.0), minY)];

  if (roundedRight)
    {
      [path appendBezierPathWithArcFromPoint: NSMakePoint (maxX, minY)
                                     toPoint: NSMakePoint (maxX, minY + clampedRadius)
                                      radius: clampedRadius];
      [path lineToPoint: NSMakePoint (maxX, maxY - clampedRadius)];
      [path appendBezierPathWithArcFromPoint: NSMakePoint (maxX, maxY)
                                     toPoint: NSMakePoint (maxX - clampedRadius, maxY)
                                      radius: clampedRadius];
    }
  else
    {
      [path lineToPoint: NSMakePoint (maxX, minY)];
      [path lineToPoint: NSMakePoint (maxX, maxY)];
    }

  [path lineToPoint: NSMakePoint (minX + (roundedLeft ? clampedRadius : 0.0), maxY)];

  if (roundedLeft)
    {
      [path appendBezierPathWithArcFromPoint: NSMakePoint (minX, maxY)
                                     toPoint: NSMakePoint (minX, maxY - clampedRadius)
                                      radius: clampedRadius];
      [path lineToPoint: NSMakePoint (minX, minY + clampedRadius)];
      [path appendBezierPathWithArcFromPoint: NSMakePoint (minX, minY)
                                     toPoint: NSMakePoint (minX + clampedRadius, minY)
                                      radius: clampedRadius];
    }
  else
    {
      [path lineToPoint: NSMakePoint (minX, maxY)];
      [path lineToPoint: NSMakePoint (minX, minY)];
    }

  [path closePath];
  return path;
}

static void
GnomeThemeFillAndStrokeRoundedRect(NSRect rect,
                                   CGFloat radius,
                                   NSColor *fillColor,
                                   NSColor *strokeColor,
                                   CGFloat strokeWidth)
{
  NSBezierPath *path = GnomeThemeRoundedPath (rect, radius);

  if (fillColor != nil)
    {
      [fillColor set];
      [path fill];
    }

  if (strokeColor != nil && strokeWidth > 0.0)
    {
      [strokeColor set];
      [path setLineWidth: strokeWidth];
      [path stroke];
    }
}

static BOOL
GnomeThemeViewHasFocus(NSView *view)
{
  id firstResponder = nil;

  if (view == nil || [view window] == nil)
    {
      return NO;
    }

  firstResponder = [[view window] firstResponder];
  if (firstResponder == view)
    {
      return YES;
    }

  if ([firstResponder respondsToSelector: @selector(delegate)])
    {
      return ([firstResponder delegate] == view);
    }

  return NO;
}

static BOOL
GnomeThemeViewEnabled(NSView *view)
{
  if (view != nil && [view respondsToSelector: @selector(isEnabled)])
    {
      return [(id)view isEnabled];
    }

  return YES;
}

static void
GnomeThemeDrawFocusRing(GnomeTheme *theme, NSRect rect, CGFloat radius)
{
  NSColor *focusColor = GnomeThemeColor (theme,
                                         @"keyboardFocusIndicatorColor",
                                         [NSColor keyboardFocusIndicatorColor]);

  focusColor = [focusColor colorWithAlphaComponent: 0.20];
  GnomeThemeFillAndStrokeRoundedRect (rect, radius, nil, focusColor, 2.5);
}

static void
GnomeThemeDrawPopupChevron(NSRect rect, NSColor *color, BOOL flipped)
{
  NSBezierPath *path = [NSBezierPath bezierPath];
  NSPoint center = NSMakePoint (NSMidX (rect), NSMidY (rect));
  CGFloat halfWidth = MIN (rect.size.width, rect.size.height) * 0.13;
  CGFloat halfHeight = halfWidth * 0.68;
  CGFloat topY = center.y + (flipped ? -halfHeight : halfHeight);
  CGFloat bottomY = center.y + (flipped ? halfHeight : -halfHeight);

  if (halfWidth < 2.5)
    {
      halfWidth = 2.5;
      halfHeight = 1.8;
    }

  [path moveToPoint: NSMakePoint (center.x - halfWidth, topY)];
  [path lineToPoint: NSMakePoint (center.x, bottomY)];
  [path lineToPoint: NSMakePoint (center.x + halfWidth, topY)];
  [path setLineWidth: 1.35];
  [path setLineCapStyle: NSRoundLineCapStyle];
  [path setLineJoinStyle: NSRoundLineJoinStyle];
  [color set];
  [path stroke];
}

static CGFloat
GnomeThemeComboBoxButtonWidth(NSRect cellFrame)
{
  return MIN (24.0, MAX (20.0, floor (cellFrame.size.height * 0.72)));
}

static NSRect
GnomeThemeComboBoxButtonRect(NSRect cellFrame)
{
  CGFloat buttonWidth = GnomeThemeComboBoxButtonWidth (cellFrame);

  return NSMakeRect (NSMaxX (cellFrame) - buttonWidth - 2.0,
                     NSMinY (cellFrame) + 2.0,
                     buttonWidth,
                     MAX (0.0, cellFrame.size.height - 4.0));
}

static void
GnomeThemeResolveEntryColors(GnomeTheme *theme,
                             NSView *view,
                             BOOL enabled,
                             BOOL focused,
                             BOOL readonlyField,
                             NSColor **fillOut,
                             NSColor **borderOut,
                             CGFloat *lineWidthOut)
{
  NSColor *windowFill = GnomeThemeColor (theme,
                                         @"windowBackgroundColor",
                                         [NSColor windowBackgroundColor]);
  NSColor *textFill = GnomeThemeColor (theme,
                                       @"textBackgroundColor",
                                       [NSColor textBackgroundColor]);
  NSColor *controlFill = GnomeThemeColor (theme,
                                          @"controlColor",
                                          [NSColor controlColor]);
  NSColor *shadowColor = GnomeThemeColor (theme,
                                          @"controlShadowColor",
                                          [NSColor controlShadowColor]);
  NSColor *fillColor = GnomeThemeBlend (textFill, controlFill, 0.64);
  NSColor *borderColor = GnomeThemeBlend (shadowColor, fillColor, 0.34);
  CGFloat lineWidth = 1.0;

  (void)view;

  if (readonlyField)
    {
      fillColor = GnomeThemeBlend (fillColor, windowFill, 0.24);
      borderColor = GnomeThemeBlend (borderColor, fillColor, 0.30);
    }

  if (enabled == NO)
    {
      fillColor = GnomeThemeBlend (fillColor, windowFill, 0.54);
      borderColor = GnomeThemeBlend (fillColor, windowFill, 0.24);
    }
  else if (focused)
    {
      fillColor = GnomeThemeBlend (fillColor, windowFill, 0.08);
      borderColor = GnomeThemeBlend (shadowColor, [NSColor blackColor], 0.12);
      lineWidth = 1.25;
    }

  if (fillOut != NULL)
    {
      *fillOut = fillColor;
    }
  if (borderOut != NULL)
    {
      *borderOut = borderColor;
    }
  if (lineWidthOut != NULL)
    {
      *lineWidthOut = lineWidth;
    }
}

static BOOL
GnomeThemeButtonCellUsesSearchImage(NSButtonCell *cell)
{
  return ([cell image] == [NSImage imageNamed: @"GSSearch"]);
}

static BOOL
GnomeThemeButtonCellUsesCancelImage(NSButtonCell *cell)
{
  return ([cell image] == [NSImage imageNamed: @"GSStop"]);
}

static void
GnomeThemeDrawSearchGlyph(NSRect rect, NSColor *color)
{
  NSBezierPath *path = [NSBezierPath bezierPath];
  CGFloat diameter = MIN (rect.size.width, rect.size.height) - 6.0;
  NSRect lensRect = GnomeThemeCenteredRect (rect, diameter, diameter);
  CGFloat handleLength = MAX (3.0, diameter * 0.34);

  lensRect.origin.x -= 1.0;
  lensRect.origin.y += 0.5;
  [path appendBezierPathWithOvalInRect: NSInsetRect (lensRect, 1.0, 1.0)];
  [path moveToPoint: NSMakePoint (NSMaxX (lensRect) - 1.5, NSMaxY (lensRect) - 1.5)];
  [path lineToPoint: NSMakePoint (NSMaxX (lensRect) + handleLength - 1.5,
                                  NSMaxY (lensRect) + handleLength - 1.5)];
  [path setLineWidth: 1.8];
  [path setLineCapStyle: NSRoundLineCapStyle];
  [path setLineJoinStyle: NSRoundLineJoinStyle];
  [color set];
  [path stroke];
}

static void
GnomeThemeDrawCancelGlyph(NSRect rect, NSColor *fillColor, NSColor *markColor)
{
  NSRect circleRect = GnomeThemeCenteredRect (rect, 14.0, 14.0);
  NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect: circleRect];
  NSBezierPath *mark = [NSBezierPath bezierPath];
  CGFloat inset = 4.4;

  [fillColor set];
  [circle fill];

  [mark moveToPoint: NSMakePoint (NSMinX (circleRect) + inset, NSMinY (circleRect) + inset)];
  [mark lineToPoint: NSMakePoint (NSMaxX (circleRect) - inset, NSMaxY (circleRect) - inset)];
  [mark moveToPoint: NSMakePoint (NSMinX (circleRect) + inset, NSMaxY (circleRect) - inset)];
  [mark lineToPoint: NSMakePoint (NSMaxX (circleRect) - inset, NSMinY (circleRect) + inset)];
  [mark setLineWidth: 1.6];
  [mark setLineCapStyle: NSRoundLineCapStyle];
  [mark setLineJoinStyle: NSRoundLineJoinStyle];
  [markColor set];
  [mark stroke];
}

static NSString *
GnomeThemeComboBoxDisplayString(NSComboBoxCell *cell)
{
  NSString *value = nil;
  id object = [cell objectValueOfSelectedItem];

  if ([object respondsToSelector: @selector(description)])
    {
      value = [object description];
    }
  if ([value length] == 0)
    {
      value = [cell stringValue];
    }

  return value;
}

static NSRect
GnomeThemeComboBoxTextRect(NSComboBoxCell *cell, NSRect cellFrame)
{
  NSRect textRect = [cell drawingRectForBounds: cellFrame];
  CGFloat leftInset = 12.0;
  CGFloat rightInset = GnomeThemeComboBoxButtonWidth (cellFrame) + 12.0;

  textRect.origin.x += leftInset;
  textRect.size.width = MAX (0.0, textRect.size.width - leftInset - rightInset);
  return textRect;
}

static NSRect
GnomeThemeProgressTrackRect(NSRect bounds)
{
  CGFloat thickness = MIN (8.0, MAX (6.0, floor (bounds.size.height * 0.24)));
  NSRect trackRect = bounds;

  trackRect.origin.x += 1.0;
  trackRect.size.width = MAX (0.0, trackRect.size.width - 2.0);
  trackRect.origin.y = floor (NSMidY (bounds) - (thickness / 2.0));
  trackRect.size.height = thickness;

  return trackRect;
}

static NSInteger
GnomeThemeSegmentIndexAtPoint(NSSegmentedCell *cell,
                              NSRect cellFrame,
                              NSPoint point)
{
  NSInteger segmentCount = [cell segmentCount];
  CGFloat explicitWidth = 0.0;
  NSInteger flexibleSegments = 0;
  CGFloat defaultWidth = 0.0;
  CGFloat cursorX = NSMinX (cellFrame);
  NSInteger index = 0;

  if (segmentCount <= 0 || NSPointInRect (point, cellFrame) == NO)
    {
      return NSNotFound;
    }

  for (index = 0; index < segmentCount; index++)
    {
      CGFloat width = [cell widthForSegment: index];

      if (width > 0.0)
        {
          explicitWidth += width;
        }
      else
        {
          flexibleSegments++;
        }
    }

  if (flexibleSegments > 0)
    {
      defaultWidth = MAX (0.0, (cellFrame.size.width - explicitWidth) / flexibleSegments);
    }

  for (index = 0; index < segmentCount; index++)
    {
      CGFloat width = [cell widthForSegment: index];

      if (width <= 0.0)
        {
          width = defaultWidth;
        }

      if (point.x < (cursorX + width) || index == (segmentCount - 1))
        {
          return index;
        }

      cursorX += width;
    }

  return NSNotFound;
}

static void
GnomeThemeDrawStepperGlyph(NSRect rect, BOOL increment, NSColor *color)
{
  CGFloat span = floor (MIN (rect.size.width, rect.size.height) * 0.28);
  NSPoint center = NSMakePoint (NSMidX (rect), NSMidY (rect));
  NSBezierPath *path = [NSBezierPath bezierPath];

  [path moveToPoint: NSMakePoint (center.x - span, center.y)];
  [path lineToPoint: NSMakePoint (center.x + span, center.y)];

  if (increment)
    {
      [path moveToPoint: NSMakePoint (center.x, center.y - span)];
      [path lineToPoint: NSMakePoint (center.x, center.y + span)];
    }

  [path setLineWidth: 1.3];
  [path setLineCapStyle: NSRoundLineCapStyle];
  [color set];
  [path stroke];
}

static BOOL
GnomeThemeScrollerShowsOverflow(NSScroller *scroller)
{
  if (scroller == nil || [scroller isEnabled] == NO)
    {
      return NO;
    }

  return ([scroller knobProportion] < 0.999);
}

static BOOL
GnomeThemeScrollerIsHorizontal(NSScroller *scroller)
{
  NSRect bounds = [scroller bounds];

  return (bounds.size.width >= bounds.size.height);
}

static NSColor *
GnomeThemeScrollerBackgroundColor(NSScroller *scroller)
{
  NSView *superview = [scroller superview];

  if ([superview isKindOfClass: [NSScrollView class]])
    {
      return [(NSScrollView *)superview backgroundColor];
    }

  return [NSColor clearColor];
}

static void
GnomeThemeEraseScrollerRect(NSScroller *scroller, NSRect rect)
{
  NSColor *backgroundColor = GnomeThemeScrollerBackgroundColor (scroller);

  if (backgroundColor != nil)
    {
      [backgroundColor set];
      NSRectFill (rect);
    }
}

static void
GnomeThemeDrawModernScroller(GnomeTheme *theme,
                             NSScroller *scroller,
                             NSRect rect,
                             NSScrollerPart hitPart,
                             BOOL isHorizontal)
{
  NSRect bounds = [scroller bounds];
  NSRect trackRect;
  NSRect knobRect = [scroller rectForPart: NSScrollerKnob];
  NSColor *backgroundColor = GnomeThemeScrollerBackgroundColor (scroller);
  NSColor *trackFill = GnomeThemeBlend (GnomeThemeColor (theme,
                                                         @"controlShadowColor",
                                                         [NSColor controlShadowColor]),
                                        backgroundColor,
                                        0.88);
  NSColor *thumbFill = GnomeThemeBlend (GnomeThemeColor (theme,
                                                         @"controlShadowColor",
                                                         [NSColor controlShadowColor]),
                                        backgroundColor,
                                        (hitPart == NSScrollerKnob) ? 0.36 : 0.48);
  CGFloat minorAxis = isHorizontal ? bounds.size.height : bounds.size.width;
  CGFloat majorInset = MAX (2.0, floor (minorAxis * 0.18));
  CGFloat trackThickness = floor (MAX (5.0, MIN (8.0, minorAxis - (majorInset * 2.0))));
  CGFloat radius = floor (trackThickness / 2.0);

  (void)rect;

  if (backgroundColor != nil)
    {
      [backgroundColor set];
      NSRectFill (bounds);
    }

  if (isHorizontal)
    {
      trackRect = NSMakeRect (NSMinX (bounds) + majorInset,
                              floor (NSMidY (bounds) - (trackThickness / 2.0)),
                              MAX (0.0, bounds.size.width - (majorInset * 2.0)),
                              trackThickness);
      knobRect = NSMakeRect (NSMinX (knobRect),
                             trackRect.origin.y,
                             knobRect.size.width,
                             trackRect.size.height);
    }
  else
    {
      trackRect = NSMakeRect (floor (NSMidX (bounds) - (trackThickness / 2.0)),
                              NSMinY (bounds) + majorInset,
                              trackThickness,
                              MAX (0.0, bounds.size.height - (majorInset * 2.0)));
      knobRect = NSMakeRect (trackRect.origin.x,
                             NSMinY (knobRect),
                             trackRect.size.width,
                             knobRect.size.height);
    }

  trackRect = NSIntersectionRect (trackRect, bounds);
  knobRect = NSIntersectionRect (knobRect, trackRect);

  if (NSIsEmptyRect (trackRect) == NO)
    {
      GnomeThemeFillAndStrokeRoundedRect (trackRect,
                                          radius,
                                          trackFill,
                                          nil,
                                          0.0);
    }

  if (NSIsEmptyRect (knobRect) == NO)
    {
      GnomeThemeFillAndStrokeRoundedRect (NSInsetRect (knobRect, 0.5, 0.5),
                                          MAX (2.0, radius - 0.5),
                                          thumbFill,
                                          nil,
                                          0.0);
    }
}

static BOOL
GnomeThemeButtonCellIsCheckbox(NSButtonCell *cell)
{
  return ([cell image] == [NSImage imageNamed: @"NSSwitch"]
    || [cell alternateImage] == [NSImage imageNamed: @"NSHighlightedSwitch"]);
}

static BOOL
GnomeThemeButtonCellIsRadio(NSButtonCell *cell)
{
  return ([cell image] == [NSImage imageNamed: @"NSRadioButton"]
    || [cell alternateImage] == [NSImage imageNamed: @"NSHighlightedRadioButton"]);
}

static BOOL
GnomeThemeButtonCellUsesLegacyReturnImage(NSButtonCell *cell)
{
  return ([cell image] == [NSImage imageNamed: @"common_ret"]
    || [cell alternateImage] == [NSImage imageNamed: @"common_retH"]);
}

static BOOL
GnomeThemeUsesScreenFonts(void)
{
  NSGraphicsContext *context = GSCurrentContext ();
  NSAffineTransform *transform = GSCurrentCTM (context);
  NSAffineTransformStruct matrix = [transform transformStruct];

  return (matrix.m11 == 1.0
    && matrix.m12 == 0.0
    && matrix.m21 == 0.0
    && fabs (matrix.m22) == 1.0);
}

static void
GnomeThemeDrawAttributedStringWithEditorLayout(NSTextFieldCell *cell,
                                               NSAttributedString *string,
                                               NSRect rect,
                                               NSView *controlView)
{
  static NSTextStorage *textStorage = nil;
  static NSLayoutManager *layoutManager = nil;
  static NSTextContainer *textContainer = nil;
  NSGraphicsContext *context = GSCurrentContext ();
  NSSize titleSize;
  NSRange glyphRange;
  BOOL viewFlipped;

  if ([string length] == 0 || NSWidth (rect) <= 0.0 || NSHeight (rect) <= 0.0)
    {
      return;
    }

  if (textStorage == nil)
    {
      textStorage = [[NSTextStorage alloc] init];
      layoutManager = [[NSLayoutManager alloc] init];
      textContainer = [[NSTextContainer alloc] initWithContainerSize: rect.size];
      [textContainer setLineFragmentPadding: 0.0];
      [textStorage addLayoutManager: layoutManager];
      [layoutManager addTextContainer: textContainer];
    }

  titleSize = [string size];
  if ([cell _shouldShortenStringForRect: rect size: titleSize length: [string length]])
    {
      string = [cell _resizeAttributedString: string forRect: rect];
    }

  [textStorage setAttributedString: string];
  [textContainer setContainerSize: rect.size];
  if ([layoutManager respondsToSelector: @selector(setUsesScreenFonts:)])
    {
      [(id)layoutManager setUsesScreenFonts: GnomeThemeUsesScreenFonts ()];
    }

  glyphRange = [layoutManager glyphRangeForBoundingRect: NSMakeRect (0.0,
                                                                     0.0,
                                                                     rect.size.width,
                                                                     rect.size.height)
                                        inTextContainer: textContainer];
  viewFlipped = (controlView != nil) ? [controlView isFlipped] : NO;

  DPSgsave (context);
  DPSrectclip (context, NSMinX (rect), NSMinY (rect), NSWidth (rect), NSHeight (rect));

  if (viewFlipped)
    {
      [layoutManager drawBackgroundForGlyphRange: glyphRange atPoint: rect.origin];
      [layoutManager drawGlyphsForGlyphRange: glyphRange atPoint: rect.origin];
    }
  else
    {
      DPStranslate (context, rect.origin.x, NSMaxY (rect));
      DPSscale (context, 1.0, -1.0);
      GSWSetViewIsFlipped (context, YES);
      [layoutManager drawBackgroundForGlyphRange: glyphRange atPoint: NSZeroPoint];
      [layoutManager drawGlyphsForGlyphRange: glyphRange atPoint: NSZeroPoint];
      GSWSetViewIsFlipped (context, NO);
    }

  DPSgrestore (context);
}

static NSFont *
GnomeThemeResolvedEditorFont(NSTextFieldCell *cell)
{
  NSFont *font = [cell font];
  GnomeTheme *theme = GnomeThemeActiveTheme ();

  if (font == nil && theme != nil)
    {
      font = [[theme settings] interfaceFont];
    }

  if (font == nil)
    {
      font = [NSFont systemFontOfSize: 12.0];
    }

  return font;
}

static NSDictionary *
GnomeThemeEditorTypingAttributes(NSTextFieldCell *cell, NSTextView *textView, NSFont *font)
{
  NSMutableDictionary *attributes = nil;
  NSDictionary *cellAttributes = [cell _nonAutoreleasedTypingAttributes];
  NSDictionary *editorAttributes = [textView typingAttributes];

  if (editorAttributes != nil)
    {
      attributes = [editorAttributes mutableCopy];
    }
  else if (cellAttributes != nil)
    {
      attributes = [cellAttributes mutableCopy];
    }
  else
    {
      attributes = [[NSMutableDictionary alloc] init];
    }

  if (cellAttributes != nil)
    {
      NSEnumerator *enumerator = [cellAttributes keyEnumerator];
      id key = nil;

      while ((key = [enumerator nextObject]) != nil)
        {
          id value = [cellAttributes objectForKey: key];

          if (value != nil)
            {
              [attributes setObject: value forKey: key];
            }
        }
      RELEASE (cellAttributes);
    }

  if (font != nil)
    {
      [attributes setObject: font forKey: NSFontAttributeName];
    }

  return AUTORELEASE (attributes);
}

static NSAttributedString *
GnomeThemeNormalizedEditorContent(NSTextFieldCell *cell, NSDictionary *attributes)
{
  NSAttributedString *cellContent = [cell attributedStringValue];
  NSMutableAttributedString *mutableContent = nil;
  NSRange fullRange;
  id value = nil;

  if ([cellContent length] == 0)
    {
      return nil;
    }

  mutableContent = AUTORELEASE ([cellContent mutableCopy]);
  fullRange = NSMakeRange (0, [mutableContent length]);

  value = [attributes objectForKey: NSFontAttributeName];
  if (value != nil)
    {
      [mutableContent addAttribute: NSFontAttributeName value: value range: fullRange];
    }

  value = [attributes objectForKey: NSForegroundColorAttributeName];
  if (value != nil)
    {
      [mutableContent addAttribute: NSForegroundColorAttributeName
                             value: value
                             range: fullRange];
    }

  value = [attributes objectForKey: NSParagraphStyleAttributeName];
  if (value != nil)
    {
      [mutableContent addAttribute: NSParagraphStyleAttributeName
                             value: value
                             range: fullRange];
    }

  return mutableContent;
}

static void
GnomeThemeApplyEditorFont(NSTextFieldCell *cell, NSText *textObject)
{
  NSFont *font = nil;
  NSTextView *textView = nil;
  NSDictionary *typingAttributes = nil;
  NSAttributedString *content = nil;
  NSTextStorage *textStorage = nil;

  if (textObject == nil)
    {
      return;
    }

  font = GnomeThemeResolvedEditorFont (cell);
  if (font == nil)
    {
      return;
    }

  [textObject setFont: font];

  if ([textObject isKindOfClass: [NSTextView class]] == NO)
    {
      return;
    }

  textView = (NSTextView *)textObject;
  [textView setTextContainerInset: NSZeroSize];
  if ([textView textContainer] != nil)
    {
      [[textView textContainer] setLineFragmentPadding: 0.0];
    }
  typingAttributes = GnomeThemeEditorTypingAttributes (cell, textView, font);
  if (typingAttributes != nil)
    {
      [textView setTypingAttributes: typingAttributes];
    }

  content = GnomeThemeNormalizedEditorContent (cell, typingAttributes);
  if (content == nil)
    {
      return;
    }

  textStorage = [textView textStorage];
  if (textStorage != nil)
    {
      [textStorage setAttributedString: content];
    }
}

static NSFont *
GnomeThemeEmphasizedFont(NSFont *font)
{
  NSFontManager *fontManager = [NSFontManager sharedFontManager];
  NSFont *boldFont = nil;

  if (font == nil || fontManager == nil)
    {
      return font;
    }

  boldFont = [fontManager convertFont: font toHaveTrait: NSBoldFontMask];
  return (boldFont != nil) ? boldFont : font;
}

static void
GnomeThemeDrawIndicatorLabel(NSButtonCell *cell,
                             NSRect titleRect,
                             NSView *controlView,
                             BOOL enabled)
{
  NSAttributedString *title = [cell attributedTitle];

  if ([title length] == 0)
    {
      return;
    }

  if (enabled == NO)
    {
      NSMutableAttributedString *mutableTitle = AUTORELEASE ([title mutableCopy]);

      [mutableTitle addAttribute: NSForegroundColorAttributeName
                           value: [NSColor disabledControlTextColor]
                           range: NSMakeRange (0, [mutableTitle length])];
      title = mutableTitle;
    }

  [cell drawTitle: title withFrame: titleRect inView: controlView];
}

static void
GnomeThemeDrawButtonLabel(NSButtonCell *cell,
                          NSRect titleRect,
                          NSView *controlView,
                          NSColor *textColor)
{
  NSAttributedString *title = [cell attributedTitle];

  if ([title length] == 0)
    {
      return;
    }

  if (textColor != nil)
    {
      NSMutableAttributedString *mutableTitle = AUTORELEASE ([title mutableCopy]);
      NSFont *font = [cell font];

      if (font == nil)
        {
          font = [NSFont controlContentFontOfSize: 0.0];
        }
      font = GnomeThemeEmphasizedFont (font);

      [mutableTitle addAttribute: NSForegroundColorAttributeName
                           value: textColor
                           range: NSMakeRange (0, [mutableTitle length])];
      if (font != nil)
        {
          [mutableTitle addAttribute: NSFontAttributeName
                               value: font
                               range: NSMakeRange (0, [mutableTitle length])];
        }
      title = mutableTitle;
    }

  [cell drawTitle: title withFrame: titleRect inView: controlView];
}

static NSRect
GnomeThemeButtonTitleRect(NSButtonCell *cell, NSRect cellFrame)
{
  NSRect titleRect = [cell drawingRectForBounds: cellFrame];
  CGFloat leftInset = ([cell isBordered] || [cell isBezeled]) ? 10.0 : 4.0;
  CGFloat rightInset = leftInset;

  if ([cell isKindOfClass: [NSPopUpButtonCell class]])
    {
      leftInset = 14.0;
      rightInset = GnomeThemeComboBoxButtonWidth (cellFrame) + 10.0;
    }

  titleRect.origin.x += leftInset;
  titleRect.size.width = MAX (0.0, titleRect.size.width - leftInset - rightInset);

  return titleRect;
}

static NSRect
GnomeThemeCenteredRect(NSRect frame, CGFloat width, CGFloat height)
{
  return NSMakeRect(NSMidX (frame) - (width / 2.0),
                    NSMidY (frame) - (height / 2.0),
                    width,
                    height);
}

static BOOL
GnomeThemeUsesCustomTopTabs(NSTabViewType type)
{
  return (type == NSTopTabsBezelBorder);
}

static BOOL
GnomeThemeButtonCellUsesPersistentAccentSelection(NSCell *cell)
{
  NSInteger showsStateByMask;

  if ([cell isKindOfClass: [NSButtonCell class]] == NO)
    {
      return NO;
    }

  showsStateByMask = [(NSButtonCell *)cell showsStateBy];
  return (showsStateByMask != NSNoCellMask);
}

static NSRect
GnomeThemeTabAccentRect(NSRect tabRect, BOOL flipped)
{
  CGFloat accentHeight = MIN (3.0, MAX (2.0, floor (tabRect.size.height * 0.12)));
  CGFloat horizontalInset = MIN (14.0, MAX (8.0, floor (tabRect.size.width * 0.18)));

  tabRect = NSInsetRect (tabRect, horizontalInset, 0.0);
  if (flipped)
    {
      tabRect.origin.y += 3.0;
    }
  else
    {
      tabRect.origin.y = NSMaxY (tabRect) - accentHeight - 3.0;
    }
  tabRect.size.height = accentHeight;

  return tabRect;
}

static void
GnomeThemeDrawTabLabel(NSString *label,
                       NSRect tabRect,
                       NSFont *font,
                       NSColor *textColor)
{
  NSDictionary *attributes = nil;
  NSSize labelSize;
  NSRect labelRect;

  if ([label length] == 0 || font == nil || textColor == nil)
    {
      return;
    }

  attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                 font, NSFontAttributeName,
                                 textColor, NSForegroundColorAttributeName,
                                 nil];
  labelSize = [label sizeWithAttributes: attributes];
  labelRect = NSInsetRect (tabRect, 14.0, 5.0);
  labelRect.origin.x = floor (NSMidX (labelRect) - (MIN (labelSize.width, labelRect.size.width) / 2.0));
  labelRect.origin.y = floor (NSMidY (labelRect) - (labelSize.height / 2.0));
  labelRect.size.height = ceil (labelSize.height);

  [label drawInRect: labelRect withAttributes: attributes];
}

@implementation GnomeTheme (Controls)

- (void) setKeyEquivalent: (NSString *)key
             forButtonCell: (NSButtonCell *)cell
{
  NSImage *returnImage = [NSImage imageNamed: @"common_ret"];
  NSImage *returnAlternateImage = [NSImage imageNamed: @"common_retH"];
  BOOL isReturnKey = [key isEqualToString: @"\r"] || [key isEqualToString: @"\n"];

  if (isReturnKey)
    {
      if ([cell image] == returnImage)
        {
          [cell setImage: nil];
          if ([cell imagePosition] == NSImageRight)
            {
              [cell setImagePosition: NSNoImage];
            }
        }

      if ([cell alternateImage] == returnAlternateImage)
        {
          [cell setAlternateImage: nil];
        }

      return;
    }

  [super setKeyEquivalent: key forButtonCell: cell];
}

- (void) drawFocusFrame: (NSRect)frame view: (NSView *)view
{
  CGFloat radius = MIN (9.0, floor (frame.size.height / 2.0));

  GnomeThemeDrawFocusRing (self, NSInsetRect (frame, -1.0, -1.0), radius + 1.0);
}

- (void) drawButton: (NSRect)frame
                 in: (NSCell *)cell
               view: (NSView *)view
              style: (int)style
              state: (GSThemeControlState)state
{
  BOOL disabled = GnomeThemeStateIsDisabled (state) || ([cell isEnabled] == NO);
  BOOL highlighted = GnomeThemeStateIsHighlighted (state);
  BOOL selected = GnomeThemeStateIsSelected (state);
  BOOL persistentAccentSelection = selected && GnomeThemeButtonCellUsesPersistentAccentSelection (cell);
  BOOL momentaryPressed = selected && (persistentAccentSelection == NO);
  BOOL focused = GnomeThemeStateIsFocused (state) || GnomeThemeViewHasFocus (view);
  BOOL popupButton = [cell isKindOfClass: [NSPopUpButtonCell class]];
  BOOL isDefaultButton = NO;
  NSColor *fillColor = nil;
  NSColor *strokeColor = nil;
  NSColor *baseFill = GnomeThemeColor (self, @"controlColor", [NSColor controlColor]);
  NSColor *backgroundFill = GnomeThemeColor (self, @"controlBackgroundColor", [NSColor controlBackgroundColor]);
  NSColor *accentFill = GnomeThemeColor (self, @"selectedControlColor", [NSColor selectedControlColor]);
  NSColor *borderBase = GnomeThemeColor (self, @"controlShadowColor", [NSColor controlShadowColor]);
  NSRect buttonRect = NSInsetRect (frame, 0.5, 0.5);
  CGFloat radius = MIN (10.0, floor (buttonRect.size.height / 2.0));
  NSString *keyEquivalent = nil;

  (void)style;

  if ([cell respondsToSelector: @selector(keyEquivalent)])
    {
      keyEquivalent = [(id)cell keyEquivalent];
      isDefaultButton = [keyEquivalent isEqualToString: @"\r"]
        || [keyEquivalent isEqualToString: @"\n"];
    }
  if (isDefaultButton == NO && view != nil && [view window] != nil)
    {
      isDefaultButton = ([[view window] defaultButtonCell] == cell);
    }

  if (popupButton)
    {
      fillColor = GnomeThemeBlend (baseFill, backgroundFill, 0.08);
      fillColor = GnomeThemeBlend (fillColor, backgroundFill, 0.04);
      strokeColor = GnomeThemeBlend (borderBase, fillColor, 0.82);

      if (disabled)
        {
          fillColor = GnomeThemeBlend (fillColor, backgroundFill, 0.24);
          strokeColor = GnomeThemeBlend (strokeColor, backgroundFill, 0.64);
        }
      else if (highlighted)
        {
          fillColor = GnomeThemeBlend (fillColor, borderBase, 0.025);
        }
    }
  else if (disabled)
    {
      fillColor = GnomeThemeBlend (baseFill, backgroundFill, 0.5);
      strokeColor = GnomeThemeBlend (borderBase, backgroundFill, 0.62);
    }
  else if (highlighted || momentaryPressed)
    {
      if (isDefaultButton)
        {
          fillColor = GnomeThemeBlend (accentFill, [NSColor blackColor], 0.18);
          strokeColor = GnomeThemeBlend (accentFill, borderBase, 0.3);
        }
      else
        {
          fillColor = GnomeThemeBlend (baseFill, borderBase, 0.34);
          fillColor = GnomeThemeBlend (fillColor, [NSColor blackColor], 0.04);
          strokeColor = GnomeThemeBlend (borderBase, fillColor, 0.28);
        }
    }
  else if (isDefaultButton || persistentAccentSelection)
    {
      fillColor = accentFill;
      strokeColor = GnomeThemeBlend (accentFill, borderBase, 0.28);
    }
  else
    {
      fillColor = GnomeThemeBlend (baseFill, backgroundFill, 0.08);
      strokeColor = GnomeThemeBlend (borderBase, fillColor, 0.62);
    }

  if (focused && disabled == NO)
    {
      GnomeThemeDrawFocusRing (self, NSInsetRect (buttonRect, -1.0, -1.0), radius + 1.0);
    }

  GnomeThemeFillAndStrokeRoundedRect (buttonRect, radius, fillColor, strokeColor, 1.0);
}

- (void) drawSegmentedControlSegment: (NSCell *)cell
                           withFrame: (NSRect)cellFrame
                              inView: (NSView *)controlView
                               style: (NSSegmentStyle)style
                               state: (GSThemeControlState)state
                         roundedLeft: (BOOL)roundedLeft
                        roundedRight: (BOOL)roundedRight
{
  BOOL selected = GnomeThemeStateIsSelected (state);
  BOOL disabled = GnomeThemeStateIsDisabled (state) || ([cell isEnabled] == NO);
  NSColor *baseFill = GnomeThemeColor (self, @"controlBackgroundColor", [NSColor controlBackgroundColor]);
  NSColor *segmentFill = GnomeThemeColor (self, @"controlColor", [NSColor controlColor]);
  NSColor *borderColor = GnomeThemeColor (self, @"controlShadowColor", [NSColor controlShadowColor]);
  NSColor *selectedFill = GnomeThemeColor (self, @"selectedInactiveColor", segmentFill);
  NSRect drawRect = NSInsetRect (cellFrame, 0.5, 0.5);
  CGFloat interiorOverlap = 1.0;
  CGFloat radius = MIN (8.0, floor (drawRect.size.height / 2.0));
  NSBezierPath *path = nil;

  (void)style;
  (void)controlView;

  borderColor = GnomeThemeBlend (borderColor, baseFill, 0.42);
  if (selected)
    {
      segmentFill = GnomeThemeBlend (selectedFill, borderColor, 0.28);
    }
  else
    {
      segmentFill = GnomeThemeBlend (segmentFill, baseFill, 0.4);
    }

  if (disabled)
    {
      segmentFill = GnomeThemeBlend (segmentFill, baseFill, 0.42);
      borderColor = GnomeThemeBlend (borderColor, baseFill, 0.5);
    }

  if (roundedLeft == NO)
    {
      drawRect.origin.x -= interiorOverlap;
      drawRect.size.width += interiorOverlap;
    }
  if (roundedRight == NO)
    {
      drawRect.size.width += interiorOverlap;
    }

  path = GnomeThemeSegmentedControlPath (drawRect, radius, roundedLeft, roundedRight);
  [segmentFill set];
  [path fill];
  [borderColor set];
  [path setLineWidth: 1.0];
  [path stroke];

  if (roundedLeft == NO)
    {
      [borderColor set];
      [NSBezierPath strokeLineFromPoint: NSMakePoint (NSMinX (drawRect), NSMinY (drawRect) + 1.0)
                                toPoint: NSMakePoint (NSMinX (drawRect), NSMaxY (drawRect) - 1.0)];
    }
}

- (void) drawBorderType: (NSBorderType)aType
                  frame: (NSRect)frame
                   view: (NSView *)view
{
  BOOL enabled = GnomeThemeViewEnabled (view);
  BOOL focused = GnomeThemeViewHasFocus (view);
  BOOL textStyleControl = ([view isKindOfClass: [NSTextField class]]
    && [view isKindOfClass: [NSScrollView class]] == NO);
  BOOL readonlyField = ([view isKindOfClass: [NSTextField class]]
    && [(NSTextField *)view isEditable] == NO
    && [(NSTextField *)view isSelectable] == NO);
  NSColor *backgroundFill = GnomeThemeColor (self, @"textBackgroundColor", [NSColor textBackgroundColor]);
  NSColor *windowFill = GnomeThemeColor (self, @"windowBackgroundColor", [NSColor windowBackgroundColor]);
  NSColor *borderColor = GnomeThemeColor (self, @"controlShadowColor", [NSColor controlShadowColor]);
  NSRect borderRect = NSInsetRect (frame, 0.5, 0.5);
  CGFloat radius = ([view isKindOfClass: [NSScrollView class]] ? 10.0 : 10.0);
  CGFloat borderWidth = 1.0;

  if (aType == NSNoBorder)
    {
      return;
    }

  if ([view isKindOfClass: [NSScrollView class]])
    {
      backgroundFill = GnomeThemeBlend (backgroundFill, windowFill, 0.18);
    }
  else
    {
      GnomeThemeResolveEntryColors (self,
                                    view,
                                    enabled,
                                    focused,
                                    readonlyField,
                                    &backgroundFill,
                                    &borderColor,
                                    &borderWidth);
    }

  if (focused && enabled && textStyleControl == NO)
    {
      GnomeThemeDrawFocusRing (self, NSInsetRect (borderRect, -0.5, -0.5), radius + 0.5);
    }

  GnomeThemeFillAndStrokeRoundedRect (borderRect,
                                      radius,
                                      backgroundFill,
                                      borderColor,
                                      borderWidth);

  if (aType == NSGrooveBorder)
    {
      NSColor *innerStroke = GnomeThemeBlend (borderColor, backgroundFill, 0.5);
      NSRect innerRect = NSInsetRect (borderRect, 2.0, 2.0);

      GnomeThemeFillAndStrokeRoundedRect (innerRect, MAX (radius - 2.0, 4.0), nil, innerStroke, 1.0);
    }
}

- (NSRect) drawProgressIndicatorBezel: (NSRect)bounds withClip: (NSRect)rect
{
  NSColor *trackFill = GnomeThemeBlend ([NSColor controlColor],
                                        [NSColor controlBackgroundColor],
                                        0.28);
  NSRect drawRect = GnomeThemeProgressTrackRect (bounds);
  CGFloat radius = floor (drawRect.size.height / 2.0);

  (void)rect;
  GnomeThemeFillAndStrokeRoundedRect (NSInsetRect (drawRect, 0.5, 0.5),
                                      radius,
                                      trackFill,
                                      nil,
                                      0.0);
  return drawRect;
}

- (void) drawProgressIndicatorBarDeterminate: (NSRect)bounds
{
  NSColor *fillColor = GnomeThemeColor (self, @"selectedControlColor", [NSColor selectedControlColor]);
  NSRect drawRect = GnomeThemeProgressTrackRect (bounds);
  CGFloat radius = floor (drawRect.size.height / 2.0);

  GnomeThemeFillAndStrokeRoundedRect (NSInsetRect (drawRect, 0.5, 0.5),
                                      radius,
                                      fillColor,
                                      nil,
                                      0.0);
}

- (void) drawSliderBorderAndBackground: (NSBorderType)aType
                                 frame: (NSRect)cellFrame
                                inCell: (NSCell *)cell
                          isHorizontal: (BOOL)horizontal
{
  NSSliderType type = [(NSSliderCell *)cell sliderType];

  if (type != NSLinearSlider)
    {
      [super drawSliderBorderAndBackground: aType
                                     frame: cellFrame
                                    inCell: cell
                              isHorizontal: horizontal];
    }
}

- (void) drawBarInside: (NSRect)rect
                inCell: (NSCell *)cell
               flipped: (BOOL)flipped
{
  NSSliderCell *sliderCell = (NSSliderCell *)cell;
  BOOL horizontal = (rect.size.width >= rect.size.height);
  CGFloat thickness = 6.0;
  CGFloat margin = 11.0;
  CGFloat fraction = 0.0;
  NSRect trackRect = rect;
  NSRect fillRect = NSZeroRect;
  NSColor *trackFill = GnomeThemeBlend ([NSColor controlColor],
                                        [NSColor controlBackgroundColor],
                                        0.3);
  NSColor *accentFill = GnomeThemeColor (self, @"selectedControlColor", [NSColor selectedControlColor]);

  if ([sliderCell maxValue] > [sliderCell minValue])
    {
      fraction = ([sliderCell doubleValue] - [sliderCell minValue])
        / ([sliderCell maxValue] - [sliderCell minValue]);
    }

  if (fraction < 0.0)
    {
      fraction = 0.0;
    }
  else if (fraction > 1.0)
    {
      fraction = 1.0;
    }

  if (horizontal)
    {
      trackRect.origin.x += margin;
      trackRect.size.width -= (margin * 2.0);
      trackRect.origin.y = NSMidY (rect) - (thickness / 2.0);
      trackRect.size.height = thickness;

      fillRect = trackRect;
      fillRect.size.width = trackRect.size.width * fraction;
    }
  else
    {
      trackRect.origin.y += margin;
      trackRect.size.height -= (margin * 2.0);
      trackRect.origin.x = NSMidX (rect) - (thickness / 2.0);
      trackRect.size.width = thickness;

      fillRect = trackRect;
      fillRect.size.height = trackRect.size.height * fraction;
      if (flipped == NO)
        {
          fillRect.origin.y = NSMaxY (trackRect) - fillRect.size.height;
        }
    }

  GnomeThemeFillAndStrokeRoundedRect (NSInsetRect (trackRect, 0.0, 0.0),
                                      thickness / 2.0,
                                      trackFill,
                                      nil,
                                      0.0);

  if (fillRect.size.width > 0.0 && fillRect.size.height > 0.0)
    {
      GnomeThemeFillAndStrokeRoundedRect (fillRect,
                                          thickness / 2.0,
                                          accentFill,
                                          nil,
                                          0.0);
    }
}

- (void) drawKnobInCell: (NSCell *)cell
{
  NSSliderCell *sliderCell = (NSSliderCell *)cell;
  NSView *controlView = [cell controlView];
  NSRect knobRect = [sliderCell knobRectFlipped: [controlView isFlipped]];
  BOOL enabled = [cell isEnabled];
  BOOL focused = GnomeThemeViewHasFocus (controlView) && enabled;
  NSColor *fillColor = GnomeThemeBlend (GnomeThemeColor (self,
                                                         @"textBackgroundColor",
                                                         [NSColor textBackgroundColor]),
                                        [NSColor controlBackgroundColor],
                                        0.1);
  NSColor *strokeColor = GnomeThemeBlend (GnomeThemeColor (self,
                                                           @"controlShadowColor",
                                                           [NSColor controlShadowColor]),
                                          fillColor,
                                          0.24);
  CGFloat knobSize = 16.0;

  knobRect = GnomeThemeCenteredRect (knobRect, knobSize, knobSize);
  if (controlView != nil)
    {
      knobRect = [controlView centerScanRect: knobRect];
    }

  if (enabled == NO)
    {
      fillColor = GnomeThemeBlend (fillColor, [NSColor controlBackgroundColor], 0.35);
      strokeColor = GnomeThemeBlend (strokeColor, [NSColor controlBackgroundColor], 0.35);
    }

  if (focused)
    {
      strokeColor = GnomeThemeBlend (GnomeThemeColor (self,
                                                      @"selectedControlColor",
                                                      [NSColor selectedControlColor]),
                                     strokeColor,
                                     0.35);
    }

  GnomeThemeFillAndStrokeRoundedRect (NSInsetRect (knobRect, 0.5, 0.5),
                                      knobSize / 2.0,
                                      fillColor,
                                      strokeColor,
                                      focused ? 1.4 : 1.0);
}

- (void) drawScrollerRect: (NSRect)rect
                   inView: (NSView *)view
                  hitPart: (NSScrollerPart)hitPart
             isHorizontal: (BOOL)isHorizontal
{
  NSScroller *scroller = (NSScroller *)view;
  if (GnomeThemeScrollerShowsOverflow (scroller) == NO)
    {
      GnomeThemeEraseScrollerRect (scroller, [scroller bounds]);
      return;
    }

  GnomeThemeDrawModernScroller (self, scroller, rect, hitPart, isHorizontal);
}

- (NSRect) stepperUpButtonRectWithFrame: (NSRect)frame
{
  CGFloat rightWidth = ceil (frame.size.width / 2.0);

  return NSMakeRect (NSMaxX (frame) - rightWidth,
                     frame.origin.y,
                     rightWidth,
                     frame.size.height);
}

- (NSRect) stepperDownButtonRectWithFrame: (NSRect)frame
{
  CGFloat leftWidth = floor (frame.size.width / 2.0);

  return NSMakeRect (frame.origin.x,
                     frame.origin.y,
                     leftWidth,
                     frame.size.height);
}

- (void) drawStepperBorder: (NSRect)frame
{
  NSRect drawRect = NSInsetRect (frame, 0.5, 0.5);
  NSColor *baseFill = GnomeThemeBlend (GnomeThemeColor (self,
                                                        @"controlColor",
                                                        [NSColor controlColor]),
                                       GnomeThemeColor (self,
                                                        @"windowBackgroundColor",
                                                        [NSColor windowBackgroundColor]),
                                       0.10);
  NSColor *strokeColor = GnomeThemeBlend (GnomeThemeColor (self,
                                                           @"controlShadowColor",
                                                           [NSColor controlShadowColor]),
                                          baseFill,
                                          0.76);
  NSColor *separatorColor = GnomeThemeBlend (strokeColor, baseFill, 0.72);
  CGFloat radius = MIN (8.0, floor (drawRect.size.height / 2.0));
  CGFloat separatorX = NSMinX (drawRect) + floor (drawRect.size.width / 2.0);
  NSBezierPath *path = GnomeThemeSegmentedControlPath (drawRect, radius, NO, YES);

  [baseFill set];
  [path fill];
  [strokeColor set];
  [path setLineWidth: 1.0];
  [path stroke];

  [separatorColor set];
  [NSBezierPath strokeLineFromPoint: NSMakePoint (separatorX, NSMinY (drawRect) + 6.0)
                            toPoint: NSMakePoint (separatorX, NSMaxY (drawRect) - 6.0)];
}

- (void) drawStepperUpButton: (NSRect)aRect
{
  GnomeThemeDrawStepperGlyph (aRect, YES, [NSColor controlTextColor]);
}

- (void) drawStepperHighlightUpButton: (NSRect)aRect
{
  NSColor *fillColor = GnomeThemeBlend ([NSColor controlColor],
                                        [NSColor controlBackgroundColor],
                                        0.34);
  NSBezierPath *path = GnomeThemeSegmentedControlPath (NSInsetRect (aRect, 1.0, 1.0),
                                                       MIN (8.0, floor (aRect.size.height / 2.0)),
                                                       NO,
                                                       YES);

  [fillColor set];
  [path fill];
  [self drawStepperUpButton: aRect];
}

- (void) drawStepperDownButton: (NSRect)aRect
{
  GnomeThemeDrawStepperGlyph (aRect, NO, [NSColor controlTextColor]);
}

- (void) drawStepperHighlightDownButton: (NSRect)aRect
{
  NSColor *fillColor = GnomeThemeBlend ([NSColor controlColor],
                                        [NSColor controlBackgroundColor],
                                        0.34);
  NSBezierPath *path = [NSBezierPath bezierPathWithRect: NSInsetRect (aRect, 1.0, 1.0)];

  [fillColor set];
  [path fill];
  [self drawStepperDownButton: aRect];
}

- (void) drawSwitchInRect: (NSRect)rect
                 forState: (NSControlStateValue)state
                  enabled: (BOOL)enabled
{
  NSRect trackRect = NSInsetRect (rect, 4.0, 6.0);
  CGFloat radius = floor (trackRect.size.height / 2.0);
  CGFloat knobSize = trackRect.size.height - 4.0;
  NSRect knobRect = NSMakeRect (trackRect.origin.x + 2.0,
                                trackRect.origin.y + 2.0,
                                knobSize,
                                knobSize);
  NSColor *trackFill = nil;
  NSColor *trackStroke = GnomeThemeColor (self, @"controlShadowColor", [NSColor controlShadowColor]);

  if (state == NSOnState)
    {
      trackFill = GnomeThemeColor (self, @"selectedControlColor", [NSColor selectedControlColor]);
      knobRect.origin.x = NSMaxX (trackRect) - knobSize - 2.0;
    }
  else
    {
      trackFill = GnomeThemeBlend ([NSColor controlColor], [NSColor controlBackgroundColor], 0.25);
    }

  if (enabled == NO)
    {
      trackFill = GnomeThemeBlend (trackFill, [NSColor controlBackgroundColor], 0.35);
      trackStroke = GnomeThemeBlend (trackStroke, [NSColor controlBackgroundColor], 0.35);
    }

  GnomeThemeFillAndStrokeRoundedRect (NSInsetRect (trackRect, 0.5, 0.5),
                                      radius,
                                      trackFill,
                                      trackStroke,
                                      1.0);
  GnomeThemeFillAndStrokeRoundedRect (NSInsetRect (knobRect, 0.5, 0.5),
                                      knobSize / 2.0,
                                      [NSColor textBackgroundColor],
                                      trackStroke,
                                      1.0);
}

- (void) drawPopUpButtonCellInteriorWithFrame: (NSRect)cellFrame
                                     withCell: (NSCell *)cell
                                       inView: (NSView *)controlView
{
  GnomeTheme *theme = GnomeThemeActiveTheme ();
  NSRect buttonRect = GnomeThemeComboBoxButtonRect (cellFrame);
  NSColor *buttonFill = GnomeThemeBlend (GnomeThemeColor (theme,
                                                          @"controlColor",
                                                          [NSColor controlColor]),
                                         GnomeThemeColor (theme,
                                                          @"windowBackgroundColor",
                                                          [NSColor windowBackgroundColor]),
                                         0.12);
  NSColor *separatorColor = GnomeThemeBlend (GnomeThemeColor (theme,
                                                              @"controlShadowColor",
                                                              [NSColor controlShadowColor]),
                                             buttonFill,
                                             0.8);
  NSColor *arrowColor = GnomeThemeBlend ([NSColor controlTextColor],
                                         [NSColor controlBackgroundColor],
                                         0.16);

  (void)cell;
  [separatorColor set];
  [NSBezierPath strokeLineFromPoint: NSMakePoint (NSMinX (buttonRect) + 0.5, NSMinY (buttonRect) + 8.0)
                            toPoint: NSMakePoint (NSMinX (buttonRect) + 0.5, NSMaxY (buttonRect) - 8.0)];

  GnomeThemeDrawPopupChevron (NSInsetRect (buttonRect, 6.0, 6.0),
                              arrowColor,
                              [controlView isFlipped]);
}

- (NSRect) tabViewContentRectForBounds: (NSRect)aRect
                           tabViewType: (NSTabViewType)type
                               tabView: (NSTabView *)view
{
  return [super tabViewContentRectForBounds: aRect
                                tabViewType: type
                                    tabView: view];
}

- (void) drawTabViewBezelRect: (NSRect)aRect
                  tabViewType: (NSTabViewType)type
                       inView: (NSView *)view
{
  NSTabView *tabView = (NSTabView *)view;
  NSRect contentRect;
  NSRect panelRect;
  NSColor *panelFill = nil;
  NSColor *panelStroke = nil;

  if ([view isKindOfClass: [NSTabView class]] == NO
    || GnomeThemeUsesCustomTopTabs (type) == NO)
    {
      [super drawTabViewBezelRect: aRect tabViewType: type inView: view];
      return;
    }

  contentRect = [super tabViewContentRectForBounds: aRect
                                       tabViewType: type
                                           tabView: tabView];
  panelRect = NSInsetRect (contentRect, 0.5, 0.5);
  panelFill = GnomeThemeBlend (GnomeThemeColor (self,
                                                @"textBackgroundColor",
                                                [NSColor textBackgroundColor]),
                               GnomeThemeColor (self,
                                                @"windowBackgroundColor",
                                                [NSColor windowBackgroundColor]),
                               0.08);
  panelStroke = GnomeThemeBlend (GnomeThemeColor (self,
                                                  @"controlShadowColor",
                                                  [NSColor controlShadowColor]),
                                 panelFill,
                                 0.18);

  if ([tabView drawsBackground])
    {
      GnomeThemeFillAndStrokeRoundedRect (panelRect, 11.0, panelFill, panelStroke, 1.0);
    }
  else
    {
      GnomeThemeFillAndStrokeRoundedRect (panelRect, 11.0, nil, panelStroke, 1.0);
    }
}

- (void) drawTabViewRect: (NSRect)rect
                  inView: (NSView *)view
               withItems: (NSArray *)items
            selectedItem: (NSTabViewItem *)selectedItem
{
  NSTabView *tabView = (NSTabView *)view;
  NSTabViewItem *selectedTab = selectedItem;
  NSTabViewType type = [tabView tabViewType];
  BOOL truncate = [tabView allowsTruncatedLabels];
  BOOL flipped = [view isFlipped];
  NSRect bounds = [view bounds];
  CGFloat tabHeight = [self tabHeightForType: type];
  NSFont *font = nil;
  NSColor *panelFill = nil;
  NSColor *tabFill = nil;
  NSColor *tabStroke = nil;
  NSColor *pressedFill = nil;
  NSColor *selectedStroke = nil;
  NSColor *selectedTextColor = nil;
  NSColor *inactiveTextColor = nil;
  NSColor *accentColor = nil;
  NSEnumerator *enumerator = nil;
  NSTabViewItem *item = nil;
  CGFloat cursorX = 12.0;
  CGFloat gap = 8.0;

  if ([view isKindOfClass: [NSTabView class]] == NO
    || GnomeThemeUsesCustomTopTabs (type) == NO)
    {
      [super drawTabViewRect: rect
                      inView: view
                   withItems: items
                selectedItem: selectedItem];
      return;
    }

  panelFill = GnomeThemeBlend (GnomeThemeColor (self,
                                                @"textBackgroundColor",
                                                [NSColor textBackgroundColor]),
                               GnomeThemeColor (self,
                                                @"windowBackgroundColor",
                                                [NSColor windowBackgroundColor]),
                               0.08);
  tabFill = GnomeThemeBlend (GnomeThemeColor (self,
                                              @"controlBackgroundColor",
                                              [NSColor controlBackgroundColor]),
                             GnomeThemeColor (self,
                                              @"windowBackgroundColor",
                                              [NSColor windowBackgroundColor]),
                             0.35);
  tabStroke = GnomeThemeBlend (GnomeThemeColor (self,
                                                @"controlShadowColor",
                                                [NSColor controlShadowColor]),
                               tabFill,
                               0.35);
  pressedFill = GnomeThemeBlend (tabFill,
                                 GnomeThemeColor (self,
                                                  @"selectedControlColor",
                                                  [NSColor selectedControlColor]),
                                 0.14);
  selectedStroke = GnomeThemeBlend (GnomeThemeColor (self,
                                                     @"controlShadowColor",
                                                     [NSColor controlShadowColor]),
                                    panelFill,
                                    0.22);
  selectedTextColor = GnomeThemeColor (self, @"controlTextColor", [NSColor controlTextColor]);
  inactiveTextColor = GnomeThemeBlend (selectedTextColor,
                                       GnomeThemeColor (self,
                                                        @"controlShadowColor",
                                                        [NSColor controlShadowColor]),
                                       0.35);
  accentColor = GnomeThemeColor (self, @"selectedControlColor", [NSColor selectedControlColor]);
  font = [tabView font];
  if (font == nil)
    {
      font = [[self settings] interfaceFont];
    }
  if (font == nil)
    {
      font = [NSFont systemFontOfSize: [NSFont systemFontSize]];
    }

  enumerator = [items objectEnumerator];
  while ((item = [enumerator nextObject]) != nil)
    {
      BOOL selected = (item == selectedTab);
      BOOL pressed = ([item tabState] == NSPressedTab);
      NSString *label = [item label];
      NSSize labelSize = [item sizeOfLabel: truncate];
      CGFloat tabWidth = ceil (MAX (labelSize.width + 34.0, 92.0));
      NSRect tabRect = NSMakeRect (cursorX,
                                   flipped ? 4.0 : (NSMaxY (bounds) - tabHeight + 4.0),
                                   tabWidth,
                                   tabHeight - 5.0);
      NSRect drawRect = tabRect;

      if (selected == NO)
        {
          if (flipped)
            {
              drawRect.origin.y += 4.0;
              drawRect.size.height -= 7.0;
            }
          else
            {
              drawRect.size.height -= 7.0;
            }
        }

      if ([label length] == 0)
        {
          cursorX += tabWidth + gap;
          continue;
        }

      [item drawLabel: truncate inRect: drawRect];

      if (truncate
        && labelSize.width > NSWidth (drawRect) - 28.0
        && [item respondsToSelector: @selector(_truncatedLabel)])
        {
          label = [item _truncatedLabel];
        }

      if (selected)
        {
          NSRect accentRect = GnomeThemeTabAccentRect (drawRect, flipped);

          GnomeThemeFillAndStrokeRoundedRect (NSInsetRect (drawRect, 0.5, 0.5),
                                              10.0,
                                              panelFill,
                                              selectedStroke,
                                              1.0);
          GnomeThemeFillAndStrokeRoundedRect (accentRect,
                                              accentRect.size.height / 2.0,
                                              accentColor,
                                              nil,
                                              0.0);
          GnomeThemeDrawTabLabel (label, drawRect, font, selectedTextColor);
        }
      else
        {
          GnomeThemeFillAndStrokeRoundedRect (NSInsetRect (drawRect, 0.5, 0.5),
                                              10.0,
                                              pressed ? pressedFill : tabFill,
                                              tabStroke,
                                              1.0);
          GnomeThemeDrawTabLabel (label, drawRect, font, inactiveTextColor);
        }

      cursorX += tabWidth + gap;
    }
}

@end

@implementation GnomeTheme (Overrides)

- (void) _overrideNSScrollerMethod_drawRect: (NSRect)rect
{
  typedef void (*DrawRectIMP)(id, SEL, NSRect);
  DrawRectIMP originalIMP = (DrawRectIMP)[[GSTheme theme] overriddenMethod: _cmd for: self];
  NSScroller *scroller = (NSScroller *)self;
  GnomeTheme *theme = GnomeThemeActiveTheme ();

  if (theme == nil)
    {
      if (originalIMP != NULL)
        {
          originalIMP (self, _cmd, rect);
        }
      return;
    }

  if ([scroller arrowsPosition] != NSScrollerArrowsNone)
    {
      [scroller setArrowsPosition: NSScrollerArrowsNone];
      return;
    }

  if (GnomeThemeScrollerShowsOverflow (scroller) == NO)
    {
      GnomeThemeEraseScrollerRect (scroller, rect);
      return;
    }

  [theme drawScrollerRect: rect
                   inView: scroller
                  hitPart: [scroller hitPart]
             isHorizontal: GnomeThemeScrollerIsHorizontal (scroller)];
}

- (void) _overrideNSScrollerMethod_drawKnobSlotInRect: (NSRect)slotRect
                                             highlight: (BOOL)flag
{
  NSScroller *scroller = (NSScroller *)self;
  GnomeTheme *theme = GnomeThemeActiveTheme ();

  (void)flag;

  if (theme == nil)
    {
      return;
    }

  if (GnomeThemeScrollerShowsOverflow (scroller) == NO)
    {
      GnomeThemeEraseScrollerRect (scroller, slotRect);
      return;
    }

  GnomeThemeDrawModernScroller (theme,
                                scroller,
                                slotRect,
                                [scroller hitPart],
                                GnomeThemeScrollerIsHorizontal (scroller));
}

- (NSRect) _overrideNSTextFieldCellMethod_titleRectForBounds: (NSRect)aRect
{
  typedef NSRect (*TitleRectIMP)(id, SEL, NSRect);
  TitleRectIMP originalIMP = (TitleRectIMP)[[GSTheme theme] overriddenMethod: _cmd for: self];
  NSTextFieldCell *cell = (NSTextFieldCell *)self;
  NSRect titleRect = (originalIMP != NULL) ? originalIMP (self, _cmd, aRect) : aRect;
  NSFont *font = GnomeThemeResolvedEditorFont (cell);
  NSDictionary *attributes = nil;
  NSSize titleSize;

  attributes = [NSDictionary dictionaryWithObject: font forKey: NSFontAttributeName];
  titleSize = [@"Ag" sizeWithAttributes: attributes];

  if ([cell isBezeled] || [cell isBordered])
    {
      BOOL readonlyField = ([cell isEditable] == NO && [cell isSelectable] == NO);
      CGFloat horizontalInset = readonlyField ? 10.0 : 4.0;

      titleRect.origin.x += horizontalInset;
      titleRect.size.width -= (horizontalInset * 2.0);
    }

  titleRect.origin.y = aRect.origin.y + floor ((aRect.size.height - titleSize.height) / 2.0);
  titleRect.size.height = ceil (titleSize.height);

  return titleRect;
}

- (NSText *) _overrideNSTextFieldCellMethod_setUpFieldEditorAttributes: (NSText *)textObject
{
  typedef NSText *(*SetUpFieldEditorAttributesIMP)(id, SEL, NSText *);
  SetUpFieldEditorAttributesIMP originalIMP
    = (SetUpFieldEditorAttributesIMP)[[GSTheme theme] overriddenMethod: _cmd for: self];
  NSTextFieldCell *cell = (NSTextFieldCell *)self;
  NSText *editor = textObject;

  if (originalIMP != NULL)
    {
      editor = originalIMP (self, _cmd, textObject);
    }

  GnomeThemeApplyEditorFont (cell, editor);
  return editor;
}

- (void) _overrideNSTextFieldCellMethod_drawInteriorWithFrame: (NSRect)cellFrame
                                                       inView: (NSView *)controlView
{
  NSTextFieldCell *cell = (NSTextFieldCell *)self;

  if ([cell _inEditing])
    {
      [cell _drawEditorWithFrame: cellFrame inView: controlView];
      return;
    }

  GnomeThemeDrawAttributedStringWithEditorLayout (cell,
                                                  [cell _drawAttributedString],
                                                  [cell titleRectForBounds: cellFrame],
                                                  controlView);
}

- (void) _overrideNSSegmentedCellMethod_drawSegment: (NSInteger)segmentIndex
                                            inFrame: (NSRect)frame
                                           withView: (NSView *)view
{
  typedef void (*DrawSegmentIMP)(id, SEL, NSInteger, NSRect, NSView *);
  DrawSegmentIMP originalIMP = (DrawSegmentIMP)[[GSTheme theme] overriddenMethod: _cmd for: self];
  GnomeTheme *theme = GnomeThemeActiveTheme ();
  NSSegmentedCell *cell = (NSSegmentedCell *)self;
  NSString *label = [cell labelForSegment: segmentIndex];
  NSImage *segmentImage = [cell imageForSegment: segmentIndex];
  BOOL selected = NO;
  GSThemeControlState state;
  BOOL roundedLeft = (segmentIndex == 0);
  BOOL roundedRight = (segmentIndex == ([cell segmentCount] - 1));
  NSView *controlView = [cell controlView];

  if ([cell trackingMode] == NSSegmentSwitchTrackingSelectOne)
    {
      selected = ([cell selectedSegment] == segmentIndex);
    }
  else
    {
      selected = [cell isSelectedForSegment: segmentIndex];
    }

  state = selected ? GSThemeSelectedState : GSThemeNormalState;

  if (originalIMP != NULL)
    {
      originalIMP (self, _cmd, segmentIndex, frame, view);
    }

  if (theme == nil)
    {
      return;
    }

  [theme drawSegmentedControlSegment: cell
                           withFrame: frame
                              inView: (controlView != nil) ? controlView : view
                               style: [cell segmentStyle]
                               state: state
                         roundedLeft: roundedLeft
                        roundedRight: roundedRight];

  if ([label length] > 0)
    {
      NSMutableDictionary *attributes = [[cell _nonAutoreleasedTypingAttributes] mutableCopy];
      NSFont *font = GnomeThemeEmphasizedFont ([attributes objectForKey: NSFontAttributeName]);
      NSSize textSize = [label sizeWithAttributes: attributes];
      CGFloat availableWidth = MAX (0.0, frame.size.width - 10.0);
      CGFloat drawWidth = MIN (availableWidth, ceil (textSize.width));
      NSRect textFrame = NSMakeRect (floor (NSMidX (frame) - (drawWidth / 2.0)),
                                     floor (NSMidY (frame) - (textSize.height / 2.0)),
                                     drawWidth,
                                     ceil (textSize.height));

      if (font != nil)
        {
          [attributes setObject: font forKey: NSFontAttributeName];
          textSize = [label sizeWithAttributes: attributes];
          drawWidth = MIN (availableWidth, ceil (textSize.width));
          textFrame = NSMakeRect (floor (NSMidX (frame) - (drawWidth / 2.0)),
                                  floor (NSMidY (frame) - (textSize.height / 2.0)),
                                  drawWidth,
                                  ceil (textSize.height));
        }

      if (view != nil)
        {
          textFrame = [view centerScanRect: textFrame];
        }

      [label drawInRect: textFrame withAttributes: attributes];
      RELEASE (attributes);
    }

  if (segmentImage != nil)
    {
      NSSize size = [segmentImage size];
      NSRect destinationRect = NSMakeRect (MAX (NSMidX (frame) - (size.width / 2.0), 0.0),
                                           MAX (NSMidY (frame) - (size.height / 2.0), 0.0),
                                           size.width,
                                           size.height);

      if (view != nil)
        {
          destinationRect = [view centerScanRect: destinationRect];
        }

      [segmentImage drawInRect: destinationRect
                      fromRect: NSZeroRect
                     operation: NSCompositeSourceOver
                      fraction: 1.0];
    }
}

- (void) _overrideNSPopUpButtonCellMethod_drawInteriorWithFrame: (NSRect)cellFrame
                                                         inView: (NSView *)controlView
{
  typedef void (*DrawInteriorIMP)(id, SEL, NSRect, NSView *);
  DrawInteriorIMP originalIMP = (DrawInteriorIMP)[[GSTheme theme] overriddenMethod: _cmd for: self];
  NSPopUpButtonCell *cell = (NSPopUpButtonCell *)self;
  NSPopUpArrowPosition originalArrowPosition = [cell arrowPosition];
  NSMenuItem *item = [cell menuItem];
  NSImage *arrowImage = [cell _currentArrowImage];
  NSImage *savedImage = nil;
  NSRect contentFrame = cellFrame;
  NSFont *originalFont = [cell font];
  NSFont *popupFont = GnomeThemeEmphasizedFont (originalFont);

  if (item != nil && [item image] == arrowImage)
    {
      savedImage = RETAIN ([item image]);
      [item setImage: nil];
    }

  [cell setArrowPosition: NSPopUpNoArrow];
  contentFrame.origin.x += 10.0;
  contentFrame.size.width = MAX (0.0, contentFrame.size.width - 16.0);
  if (popupFont != nil)
    {
      [cell setFont: popupFont];
    }

  if (originalIMP != NULL)
    {
      originalIMP (self, _cmd, contentFrame, controlView);
    }

  [cell setArrowPosition: originalArrowPosition];
  if (popupFont != nil)
    {
      [cell setFont: originalFont];
    }

  if (item != nil && savedImage != nil)
    {
      [item setImage: savedImage];
      RELEASE (savedImage);
    }
}

- (void) _overrideNSComboBoxCellMethod_drawInteriorWithFrame: (NSRect)cellFrame
                                                      inView: (NSView *)controlView
{
  typedef void (*DrawInteriorIMP)(id, SEL, NSRect, NSView *);
  DrawInteriorIMP originalIMP = (DrawInteriorIMP)[[GSTheme theme] overriddenMethod: _cmd for: self];
  GnomeTheme *theme = GnomeThemeActiveTheme ();
  NSComboBoxCell *cell = (NSComboBoxCell *)self;
  NSRect buttonRect = GnomeThemeComboBoxButtonRect (cellFrame);
  NSRect textRect = GnomeThemeComboBoxTextRect (cell, cellFrame);
  NSRect interiorRect = NSInsetRect (cellFrame, 1.0, 1.0);
  BOOL enabled = [(NSCell *)self isEnabled];
  BOOL focused = GnomeThemeViewHasFocus (controlView) && enabled;
  BOOL editing = ([controlView isKindOfClass: [NSControl class]]
    && [(NSControl *)controlView currentEditor] != nil);
  NSColor *entryFill = nil;
  NSColor *arrowColor = GnomeThemeColor (theme,
                                         enabled ? @"controlTextColor" : @"disabledControlTextColor",
                                         enabled ? [NSColor controlTextColor] : [NSColor disabledControlTextColor]);
  NSString *displayString = GnomeThemeComboBoxDisplayString (cell);
  NSMutableDictionary *attributes = nil;
  NSSize textSize = NSZeroSize;
  NSFont *font = nil;

  GnomeThemeResolveEntryColors (theme,
                                controlView,
                                enabled,
                                focused,
                                NO,
                                &entryFill,
                                NULL,
                                NULL);

  [cell setValue: [NSValue valueWithRect: cellFrame] forKey: @"_lastValidFrame"];

  if (editing)
    {
      if (originalIMP != NULL)
        {
          originalIMP (self, _cmd, cellFrame, controlView);
        }
      return;
    }

  [entryFill set];
  NSRectFillUsingOperation (interiorRect, NSCompositeSourceOver);

  if ([displayString length] > 0)
    {
      attributes = [[cell _nonAutoreleasedTypingAttributes] mutableCopy];
      font = GnomeThemeEmphasizedFont ([attributes objectForKey: NSFontAttributeName]);
      if (font != nil)
        {
          [attributes setObject: font forKey: NSFontAttributeName];
        }
      [attributes setObject: enabled ? [NSColor controlTextColor] : [NSColor disabledControlTextColor]
                     forKey: NSForegroundColorAttributeName];

      textSize = [displayString sizeWithAttributes: attributes];
      textRect.origin.y = floor (NSMidY (cellFrame) - (textSize.height / 2.0));
      textRect.size.height = ceil (textSize.height);
      [displayString drawInRect: textRect withAttributes: attributes];
      RELEASE (attributes);
    }

  [entryFill set];
  NSRectFillUsingOperation (NSInsetRect (buttonRect, -1.0, 0.0), NSCompositeSourceOver);

  GnomeThemeDrawPopupChevron (NSInsetRect (buttonRect, 6.0, 6.0),
                              arrowColor,
                              [controlView isFlipped]);
}

- (BOOL) _overrideNSComboBoxCellMethod_trackMouse: (NSEvent *)theEvent
                                           inRect: (NSRect)cellFrame
                                           ofView: (NSView *)controlView
                                     untilMouseUp: (BOOL)flag
{
  typedef BOOL (*TrackMouseIMP)(id, SEL, NSEvent *, NSRect, NSView *, BOOL);
  TrackMouseIMP originalIMP = (TrackMouseIMP)[[GSTheme theme] overriddenMethod: _cmd for: self];
  NSPoint point = [controlView convertPoint: [theEvent locationInWindow] fromView: nil];
  BOOL nonEditableCombo = ([controlView isKindOfClass: [NSComboBox class]]
    && [(NSComboBox *)controlView isEditable] == NO);
  NSRect themedButtonRect = GnomeThemeComboBoxButtonRect (cellFrame);
  NSComboBoxCell *cell = (NSComboBoxCell *)self;

  if ((nonEditableCombo && NSMouseInRect (point, cellFrame, [controlView isFlipped]))
    || NSMouseInRect (point, themedButtonRect, [controlView isFlipped]))
    {
      if ([(NSCell *)self isEnabled])
        {
          id buttonCell = [cell valueForKey: @"_buttonCell"];

          [cell _didClickWithinButton: cell];
          [(NSCell *)cell setHighlighted: NO];
          if ([buttonCell respondsToSelector: @selector(setHighlighted:)])
            {
              [buttonCell setHighlighted: NO];
            }
          [controlView setNeedsDisplay: YES];
          [controlView displayIfNeededIgnoringOpacity];
          if ([controlView window] != nil)
            {
              [[controlView window] setViewsNeedDisplay: YES];
              [[controlView window] flushWindow];
              [[controlView window] performSelector: @selector(displayIfNeeded)
                                         withObject: nil
                                         afterDelay: 0.0];
            }
          return YES;
        }
    }

  if (originalIMP != NULL)
    {
      return originalIMP (self, _cmd, theEvent, cellFrame, controlView, flag);
    }

  return NO;
}

- (void) _overrideNSComboBoxCellMethod_highlight: (BOOL)flag
                                        withFrame: (NSRect)cellFrame
                                           inView: (NSView *)controlView
{
  NSComboBoxCell *cell = (NSComboBoxCell *)self;

  if ([(NSCell *)cell isHighlighted] != flag)
    {
      [(NSCell *)cell setHighlighted: flag];
      [cell drawWithFrame: cellFrame inView: controlView];
    }
}

- (BOOL) _overrideNSSegmentedCellMethod_trackMouse: (NSEvent *)theEvent
                                            inRect: (NSRect)cellFrame
                                            ofView: (NSView *)controlView
                                      untilMouseUp: (BOOL)flag
{
  typedef BOOL (*TrackMouseIMP)(id, SEL, NSEvent *, NSRect, NSView *, BOOL);
  TrackMouseIMP originalIMP = (TrackMouseIMP)[[GSTheme theme] overriddenMethod: _cmd for: self];
  GnomeTheme *theme = GnomeThemeActiveTheme ();
  NSSegmentedCell *cell = (NSSegmentedCell *)self;
  NSPoint point = [controlView convertPoint: [theEvent locationInWindow] fromView: nil];
  NSInteger hitIndex = NSNotFound;

  if (theme == nil || [cell trackingMode] != NSSegmentSwitchTrackingSelectOne)
    {
      if (originalIMP != NULL)
        {
          return originalIMP (self, _cmd, theEvent, cellFrame, controlView, flag);
        }
      return NO;
    }

  hitIndex = GnomeThemeSegmentIndexAtPoint (cell, cellFrame, point);
  if (hitIndex == NSNotFound || [cell isEnabledForSegment: hitIndex] == NO)
    {
      if (originalIMP != NULL)
        {
          return originalIMP (self, _cmd, theEvent, cellFrame, controlView, flag);
        }
      return NO;
    }

  if ([controlView respondsToSelector: @selector(setSelectedSegment:)])
    {
      [(id)controlView setSelectedSegment: hitIndex];
    }
  else
    {
      [cell setSelectedSegment: hitIndex];
    }

  [controlView setNeedsDisplayInRect: cellFrame];

  if ([controlView isKindOfClass: [NSControl class]])
    {
      [(NSControl *)controlView sendAction: [cell action] to: [cell target]];
    }
  else
    {
      [NSApp sendAction: [cell action] to: [cell target] from: controlView];
    }

  return YES;
}

- (void) _overrideNSButtonCellMethod_drawInteriorWithFrame: (NSRect)cellFrame
                                                    inView: (NSView *)controlView
{
  typedef void (*DrawInteriorIMP)(id, SEL, NSRect, NSView *);
  DrawInteriorIMP originalIMP = (DrawInteriorIMP)[[GSTheme theme] overriddenMethod: _cmd for: self];
  NSButtonCell *cell = (NSButtonCell *)self;
  BOOL checkbox = GnomeThemeButtonCellIsCheckbox ((NSButtonCell *)self);
  BOOL radio = GnomeThemeButtonCellIsRadio ((NSButtonCell *)self);

  if (checkbox == NO && radio == NO)
    {
      BOOL defaultButton = NO;
      BOOL hasLegacyReturnImage = GnomeThemeButtonCellUsesLegacyReturnImage (cell);
      BOOL searchButton = GnomeThemeButtonCellUsesSearchImage (cell);
      BOOL cancelButton = GnomeThemeButtonCellUsesCancelImage (cell);
      BOOL hasCustomImage = ([cell image] != nil && hasLegacyReturnImage == NO);
      BOOL hasCustomAlternateImage = ([cell alternateImage] != nil
        && [cell alternateImage] != [NSImage imageNamed: @"common_retH"]);
      BOOL enabled = [cell isEnabled];
      NSColor *textColor = enabled
        ? [NSColor controlTextColor]
        : [NSColor disabledControlTextColor];
      NSRect titleRect = GnomeThemeButtonTitleRect (cell, cellFrame);
      NSString *keyEquivalent = [cell keyEquivalent];

      if (searchButton || cancelButton)
        {
          GnomeTheme *theme = GnomeThemeActiveTheme ();
          NSColor *glyphColor = GnomeThemeColor (theme,
                                                 enabled ? @"controlTextColor" : @"disabledControlTextColor",
                                                 enabled ? [NSColor controlTextColor] : [NSColor disabledControlTextColor]);

          glyphColor = GnomeThemeBlend (glyphColor,
                                        GnomeThemeColor (theme,
                                                         @"controlShadowColor",
                                                         [NSColor controlShadowColor]),
                                        cancelButton ? 0.24 : 0.42);

          if (searchButton)
            {
              GnomeThemeDrawSearchGlyph (cellFrame, glyphColor);
            }
          else
            {
              NSColor *circleFill = GnomeThemeBlend (GnomeThemeColor (theme,
                                                                      @"controlShadowColor",
                                                                      [NSColor controlShadowColor]),
                                                     GnomeThemeColor (theme,
                                                                      @"windowBackgroundColor",
                                                                      [NSColor windowBackgroundColor]),
                                                     0.28);

              if ([cell isHighlighted] && enabled)
                {
                  circleFill = GnomeThemeBlend (circleFill, [NSColor blackColor], 0.12);
                }
              if (enabled == NO)
                {
                  circleFill = GnomeThemeBlend (circleFill,
                                                GnomeThemeColor (theme,
                                                                 @"windowBackgroundColor",
                                                                 [NSColor windowBackgroundColor]),
                                                0.35);
                }

              GnomeThemeDrawCancelGlyph (cellFrame,
                                         circleFill,
                                         GnomeThemeColor (theme,
                                                          @"selectedControlTextColor",
                                                          [NSColor whiteColor]));
            }
          return;
        }

      if (hasCustomImage || hasCustomAlternateImage)
        {
          if (originalIMP != NULL)
            {
              originalIMP (self, _cmd, cellFrame, controlView);
            }
          return;
        }

      defaultButton = ([keyEquivalent isEqualToString: @"\r"]
        || [keyEquivalent isEqualToString: @"\n"]);
      if (defaultButton == NO && controlView != nil && [controlView window] != nil)
        {
          defaultButton = ([[controlView window] defaultButtonCell] == cell);
        }

      if (defaultButton && enabled)
        {
          textColor = [NSColor selectedControlTextColor];
        }

      if ([cell isHighlighted])
        {
          titleRect.origin.x += 1.0;
          titleRect.origin.y -= 1.0;
        }

      GnomeThemeDrawButtonLabel (cell, titleRect, controlView, textColor);
      return;
    }

  {
    GnomeTheme *theme = GnomeThemeActiveTheme ();
    BOOL enabled = [(NSButtonCell *)self isEnabled];
    BOOL highlighted = [(NSButtonCell *)self isHighlighted];
    NSInteger state = [(NSButtonCell *)self state];
    NSRect contentRect = [(NSButtonCell *)self drawingRectForBounds: cellFrame];
    CGFloat indicatorSize = MAX (18.0, floor (contentRect.size.height * 0.58));
    NSRect indicatorRect = NSMakeRect (contentRect.origin.x + 2.0,
                                       NSMidY (contentRect) - (indicatorSize / 2.0),
                                       indicatorSize,
                                       indicatorSize);
    NSRect titleRect = contentRect;
    NSColor *fillColor = nil;
    NSColor *borderColor = nil;
    NSColor *markColor = nil;
    NSBezierPath *path = nil;

    titleRect.origin.x = NSMaxX (indicatorRect) + 10.0;
    titleRect.size.width = NSMaxX (contentRect) - titleRect.origin.x;

    if (state == NSOnState || state == NSMixedState)
      {
        fillColor = [NSColor selectedControlColor];
        borderColor = GnomeThemeBlend (fillColor, [NSColor controlShadowColor], 0.25);
        markColor = [NSColor selectedControlTextColor];
      }
    else
      {
        fillColor = [NSColor textBackgroundColor];
        borderColor = [NSColor controlShadowColor];
        markColor = [NSColor controlTextColor];
      }

    if (highlighted && enabled)
      {
        fillColor = GnomeThemeBlend (fillColor, [NSColor controlShadowColor], 0.14);
      }
    if (enabled == NO)
      {
        fillColor = GnomeThemeBlend (fillColor, [NSColor controlBackgroundColor], 0.35);
        borderColor = GnomeThemeBlend (borderColor, [NSColor controlBackgroundColor], 0.35);
        markColor = [NSColor disabledControlTextColor];
      }

    if (GnomeThemeViewHasFocus (controlView) && enabled)
      {
        GnomeThemeDrawFocusRing (theme, NSInsetRect (indicatorRect, -1.0, -1.0), radio ? indicatorSize / 2.0 : 6.0);
      }

    if (radio)
      {
        path = [NSBezierPath bezierPathWithOvalInRect: NSInsetRect (indicatorRect, 0.5, 0.5)];
      }
    else
      {
        path = GnomeThemeRoundedPath (NSInsetRect (indicatorRect, 0.5, 0.5), 5.0);
      }

    [fillColor set];
    [path fill];
    [borderColor set];
    [path setLineWidth: 1.0];
    [path stroke];

    if (state == NSOnState)
      {
        if (radio)
          {
            NSRect dotRect = NSInsetRect (indicatorRect, indicatorSize * 0.28, indicatorSize * 0.28);
            NSBezierPath *dotPath = [NSBezierPath bezierPathWithOvalInRect: dotRect];

            [markColor set];
            [dotPath fill];
          }
        else
          {
            NSBezierPath *checkPath = [NSBezierPath bezierPath];
            CGFloat left = NSMinX (indicatorRect) + indicatorSize * 0.22;
            CGFloat midX = NSMinX (indicatorRect) + indicatorSize * 0.45;
            CGFloat right = NSMaxX (indicatorRect) - indicatorSize * 0.2;
            CGFloat top = NSMinY (indicatorRect) + indicatorSize * 0.28;
            CGFloat midY = NSMidY (indicatorRect) + indicatorSize * 0.08;
            CGFloat bottom = NSMaxY (indicatorRect) - indicatorSize * 0.24;

            [checkPath moveToPoint: NSMakePoint (left, midY)];
            [checkPath lineToPoint: NSMakePoint (midX, bottom)];
            [checkPath lineToPoint: NSMakePoint (right, top)];
            [checkPath setLineWidth: 2.1];
            [checkPath setLineCapStyle: NSRoundLineCapStyle];
            [checkPath setLineJoinStyle: NSRoundLineJoinStyle];
            [markColor set];
            [checkPath stroke];
          }
      }
    else if (state == NSMixedState)
      {
        NSRect dashRect = NSMakeRect (NSMinX (indicatorRect) + indicatorSize * 0.22,
                                      NSMidY (indicatorRect) - 1.5,
                                      indicatorSize * 0.56,
                                      3.0);

        GnomeThemeFillAndStrokeRoundedRect (dashRect, 1.5, markColor, nil, 0.0);
      }

    GnomeThemeDrawIndicatorLabel ((NSButtonCell *)self, titleRect, controlView, enabled);
  }
}

@end
