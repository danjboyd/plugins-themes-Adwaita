# libs-back: a cursor's hot spot isn't scaled with its image

`-[XGServer imagecursor::]` in `Source/x11/XGServerWindow.m` builds the X cursor in the pixels of the image's representation, but uses the hot spot as given, in the image's points. With a 2× representation the hot spot lands at half the distance it should.

Read on libs-back master d378734ea (the same lines as `imagecursor:` at about line 4491; `xhot` and `yhot` at 4535). Measured on 0.32.0-6+csd6, reading the cursor back with `XFixesGetCursorImage` on a private Xvfb.

## Measured

A 16×16pt image, hot spot (8,8), the middle:

| Representation | GSScaleFactor | X cursor | Hot spot | Middle |
|---|---|---|---|---|
| 16px | 1 | 16×16 | (8,8) | (8,8) |
| 32px | 1 | 32×32 | (8,8) | (16,16) |
| 32px | 2 | 32×32 | (8,8) | (16,16) |

The image here has only that one representation. A 16+32px image wasn't tried.

## Repro

```objc
NSBitmapImageRep *rep = /* 32x32 pixels, opaque */;
[rep setSize: NSMakeSize (16, 16)];
NSImage *image = [[NSImage alloc] initWithSize: NSMakeSize (16, 16)];
[image addRepresentation: rep];
NSCursor *cursor = [[NSCursor alloc] initWithImage: image hotSpot: NSMakePoint (8, 8)];
[cursor set];
/* With the pointer over a window of the app: */
XFixesCursorImage *c = XFixesGetCursorImage (display);
printf ("%dx%d hot (%d,%d)\n", c->width, c->height, c->xhot, c->yhot);
```

## Suggested fix

Scale the hot spot by the representation's pixels per point before the clamp to the representation's size:

```objc
NSSize size = [image size];

if (size.width > 0 && size.height > 0)
  {
    hotp.x = hotp.x * [rep pixelsWide] / size.width;
    hotp.y = hotp.y * [rep pixelsHigh] / size.height;
  }
```

Not built or tested. It should be checked against how the y coordinate is flipped before this point, and with non-square images.

## For the theme

The theme's two diagonal frame-resize cursors stay at 1× until this is fixed. A theme-side workaround would be passing the hot spot in pixels, but that would be wrong as soon as libs-back scales it, so the theme doesn't do it.
