"""Tutorial finger: the supplied icon (tools/assets/source/finger.png), used as drawn.

Only the white page around the glove is made transparent (flood fill from the border, so the
glove's own white stays), then it is trimmed and centred in a square.
"""

import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.join(HERE, "source", "finger.png")
SIZE = 256


def finger_image():
    """Returns (RGBA image, fingertip as fractions of the image size)."""
    src = Image.open(SOURCE).convert("RGBA")
    lum = src.convert("L")
    # 255 = light (page or glove), 0 = outline; flood the light area that touches the border.
    regions = lum.point(lambda v: 255 if v > 128 else 0)
    w, h = src.size
    for corner in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        if regions.getpixel(corner) == 255:
            ImageDraw.floodfill(regions, corner, 128)
    outside = regions.point(lambda v: 255 if v == 128 else 0)

    out = src.copy()
    alpha = out.getchannel("A")
    # Outside the glove: transparent, except the outline's soft edge (dark = opaque).
    edge = lum.point(lambda v: 255 - v)
    alpha = Image.composite(Image.composite(edge, alpha, outside), alpha, outside)
    out.putalpha(alpha)
    black = Image.new("RGBA", out.size, (0, 0, 0, 255))
    black.putalpha(alpha)
    out = Image.composite(black, out, outside)

    box = out.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
    out = out.crop(box)
    side = max(out.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    ox, oy = (side - out.width) // 2, (side - out.height) // 2
    square.alpha_composite(out, (ox, oy))

    # Fingertip: middle of the topmost opaque row, a little inside the outline.
    a = square.getchannel("A")
    top = next(y for y in range(side) if any(a.getpixel((x, y)) > 128 for x in range(side)))
    xs = [x for x in range(side) if a.getpixel((x, top + 3)) > 128]
    tip = ((min(xs) + max(xs)) / 2 / side, (top + side * 0.03) / side)
    return square.resize((SIZE, SIZE), Image.LANCZOS), tip


if __name__ == "__main__":
    import sys

    im, tip = finger_image()
    print("tip", tip)
    preview = Image.new("RGBA", (600, 300), (40, 18, 80, 255))
    preview.alpha_composite(im, (20, 20))
    preview.alpha_composite(im.resize((96, 96), Image.LANCZOS), (330, 100))
    d = ImageDraw.Draw(preview)
    tx, ty = 20 + tip[0] * SIZE, 20 + tip[1] * SIZE
    d.ellipse([tx - 4, ty - 4, tx + 4, ty + 4], fill=(255, 0, 0, 255))
    preview.save(sys.argv[1])
