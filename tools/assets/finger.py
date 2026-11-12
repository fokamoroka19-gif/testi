import math, sys
from PIL import Image, ImageDraw, ImageFilter

INK = (18, 6, 31, 255)
WHITE = (255, 252, 248, 255)
SHADE = (205, 192, 255, 255)
NAIL = (236, 228, 255, 255)
CUFF = (90, 47, 194, 255)
CUFF_DARK = (58, 26, 140, 255)
GOLD = (255, 191, 31, 255)

N = 1024


def rr(box, r):
    m = Image.new("L", (N, N), 0)
    ImageDraw.Draw(m).rounded_rectangle(box, r, fill=255)
    return m


def rotated_ellipse(center, size, angle):
    w, h = size
    tile = Image.new("L", (w, h), 0)
    ImageDraw.Draw(tile).ellipse([0, 0, w - 1, h - 1], fill=255)
    tile = tile.rotate(angle, expand=True, resample=Image.BICUBIC)
    m = Image.new("L", (N, N), 0)
    m.paste(tile, (int(center[0] - tile.width / 2), int(center[1] - tile.height / 2)))
    return m


def union(*masks):
    out = Image.new("L", (N, N), 0)
    for m in masks:
        out = Image.composite(Image.new("L", (N, N), 255), out, m)
    return out


def fill(img, mask, color, outline=0):
    if outline:
        grown = mask.filter(ImageFilter.MaxFilter(outline * 2 + 1))
        img.paste(Image.new("RGBA", (N, N), INK), (0, 0), grown)
    img.paste(Image.new("RGBA", (N, N), color), (0, 0), mask)


def shade_right(img, mask, width):
    shifted = Image.new("L", (N, N), 0)
    shifted.paste(mask, (-width, 0))
    rim = Image.composite(Image.new("L", (N, N), 0), mask, shifted)
    img.paste(Image.new("RGBA", (N, N), SHADE), (0, 0), rim)


def finger_image():
    index = rr([440, 70, 570, 600], 65)
    palm = rr([330, 470, 770, 830], 120)
    knuckles = [rr([560, 420, 668, 570], 54), rr([650, 455, 752, 600], 50), rr([735, 505, 822, 640], 44)]
    thumb = rotated_ellipse((370, 600), (130, 270), 38)
    cuff = rr([355, 780, 745, 935], 30)

    hand = union(index, palm, thumb, *knuckles)
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    # One thick outline around the whole silhouette, then the parts on top.
    fill(img, union(hand, cuff), (0, 0, 0, 0), outline=26)
    fill(img, cuff, CUFF)
    stripe = rr([355, 812, 745, 852], 0)
    img.paste(Image.new("RGBA", (N, N), GOLD), (0, 0), Image.composite(stripe, Image.new("L", (N, N), 0), cuff))
    img.paste(Image.new("RGBA", (N, N), CUFF_DARK), (0, 0), Image.composite(rr([355, 900, 745, 935], 0), Image.new("L", (N, N), 0), cuff))
    fill(img, index, WHITE)
    shade_right(img, index, 34)
    fill(img, palm, WHITE)
    shade_right(img, palm, 44)
    for k in knuckles:
        fill(img, k, WHITE, outline=9)
        shade_right(img, k, 26)
    fill(img, thumb, WHITE, outline=9)
    nail = rr([470, 100, 540, 185], 30)
    fill(img, nail, NAIL, outline=7)
    # Cuff over the wrist edge, with its own line.
    top = Image.new("L", (N, N), 0)
    ImageDraw.Draw(top).line([(355, 782), (745, 782)], fill=255, width=18)
    img.paste(Image.new("RGBA", (N, N), INK), (0, 0), Image.composite(top, Image.new("L", (N, N), 0), cuff.filter(ImageFilter.MaxFilter(19))))

    tip = (505, 70 - 26)  # top of the index finger outline
    angle = 22  # tilt so the tip points up-left (the hand comes in from the bottom right)
    img = img.rotate(angle, resample=Image.BICUBIC, center=(N / 2, N / 2))
    a = math.radians(angle)
    dx, dy = tip[0] - N / 2, tip[1] - N / 2
    tip = (N / 2 + dx * math.cos(a) + dy * math.sin(a), N / 2 - dx * math.sin(a) + dy * math.cos(a))
    box = img.getchannel("A").getbbox()
    img = img.crop(box)
    tip = (tip[0] - box[0], tip[1] - box[1])
    side = max(img.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    ox, oy = (side - img.width) // 2, (side - img.height) // 2
    square.alpha_composite(img, (ox, oy))
    tip = ((tip[0] + ox) / side, (tip[1] + oy) / side)
    return square.resize((256, 256), Image.LANCZOS), tip


if __name__ == "__main__":
    im, tip = finger_image()
    print("tip anchor", tip)
    big = Image.new("RGBA", (600, 300), (40, 18, 80, 255))
    big.alpha_composite(im, (20, 20))
    big.alpha_composite(im.resize((96, 96), Image.LANCZOS), (330, 100))
    d = ImageDraw.Draw(big)
    d.ellipse([20 + tip[0] * 256 - 4, 20 + tip[1] * 256 - 4, 20 + tip[0] * 256 + 4, 20 + tip[1] * 256 + 4], fill=(255, 0, 0, 255))
    big.save(sys.argv[1])
