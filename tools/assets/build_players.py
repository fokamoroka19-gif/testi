"""Builds the outfield players' kit textures from the character sheets, the same way the goalkeeper's
were made: each body part's front / back / side is cut from the sheet's FRONT / BACK / LEFT / RIGHT
views and packed into ReplicatedStorage/Shared/Images/<Module>.lua for the client's ImageLoader.

    python3 tools/assets/build_players.py [--preview DIR]

Needs Pillow. Sheets live in tools/assets/source/. Boxes are sheet pixels (x0, y0, x1, y1).
Rig faces (see Shared/FigureBuilder): Front = chest, Back, Left = the character's left side.
In the sheets' FRONT view the character's right arm/leg is on the image's left; in BACK the
reverse. LEFT / RIGHT views show the face towards the image's left / right, which is how the
rig's Left / Right decals read.
"""

import base64
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOURCE = os.path.join(ROOT, "tools", "assets", "source")
OUT = os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "Images")
MAX_SIDE = 100
COLORS = 64

# Body boxes shared by the three 1672x941 sheets (teammates and rival use one template).
TEMPLATE_BODY = {
    "UpperTorsoFront": (420, 150, 564, 268),
    "LowerTorsoFront": (420, 268, 564, 318),
    "UpperTorsoBack": (895, 150, 1042, 268),
    "LowerTorsoBack": (895, 268, 1042, 318),
    "UpperTorsoSide": (420, 150, 446, 268),
    "LowerTorsoSide": (420, 268, 446, 318),
    # Arms: Front from FRONT, Back from BACK, Side from the LEFT / RIGHT views.
    "RightUpperArmFront": (360, 158, 420, 255),
    "RightLowerArmFront": (352, 252, 414, 300),
    "RightHandFront": (333, 295, 402, 366),
    "LeftUpperArmFront": (562, 158, 622, 255),
    "LeftLowerArmFront": (580, 252, 642, 300),
    "LeftHandFront": (582, 295, 652, 366),
    "LeftUpperArmBack": (832, 158, 895, 255),
    "LeftLowerArmBack": (826, 252, 888, 300),
    "LeftHandBack": (810, 295, 878, 366),
    "RightUpperArmBack": (1040, 158, 1100, 255),
    "RightLowerArmBack": (1060, 252, 1122, 300),
    "RightHandBack": (1060, 295, 1128, 366),
    "LeftUpperArmSide": (700, 152, 778, 255),
    "LeftLowerArmSide": (700, 252, 780, 292),
    "LeftHandSide": (688, 286, 766, 362),
    "RightUpperArmSide": (1160, 152, 1236, 255),
    "RightLowerArmSide": (1160, 252, 1238, 292),
    "RightHandSide": (1162, 286, 1240, 362),
    # Legs: the upper leg carries the shorts and the knee, the lower leg the sock.
    "RightUpperLegFront": (408, 318, 494, 405),
    "LeftUpperLegFront": (494, 318, 580, 405),
    "RightLowerLegFront": (410, 400, 484, 462),
    "LeftLowerLegFront": (506, 400, 580, 462),
    "LeftUpperLegBack": (885, 318, 968, 405),
    "RightUpperLegBack": (968, 318, 1052, 405),
    "LeftLowerLegBack": (887, 400, 962, 462),
    "RightLowerLegBack": (978, 400, 1052, 462),
    "LeftUpperLegSide": (703, 355, 778, 405),
    "RightUpperLegSide": (1160, 355, 1236, 405),
    "LeftLowerLegSide": (703, 400, 778, 462),
    "RightLowerLegSide": (1160, 400, 1236, 462),
}

TEMPLATE_HEAD = {
    "HeadFront": (438, 38, 558, 142),
    "HeadBack": (903, 38, 1019, 142),
    "HeadLeft": (697, 38, 781, 142),
    "HeadRight": (1150, 38, 1236, 142),
    "HairFront": (420, 12, 572, 46),
    "HairBack": (885, 12, 1040, 46),
    "HairLeft": (690, 12, 790, 46),
    "HairRight": (1140, 12, 1240, 46),
}

# Your player: head and hair from the main sheet, the team's navy kit from teammate #7's sheet
# with the drawn numbers painted out (the chosen number and surname are printed on top in game).
MAIN_HEAD = {
    "HeadFront": (419, 78, 527, 178),
    "HeadBack": (832, 88, 932, 180),
    "HeadLeft": (624, 88, 720, 180),
    "HeadRight": (1034, 88, 1132, 180),
    "HairFront": (392, 56, 556, 92),
    "HairBack": (812, 58, 955, 94),
    "HairLeft": (612, 62, 745, 98),
    "HairRight": (1000, 62, 1140, 98),
}
ERASE_T7 = [  # sheet boxes of the drawn 7s and the back "II", and which side to take the colour from
    (474, 202, 516, 260, "both"),
    (538, 334, 570, 376, "left"),  # shorts: the right side is the white piping
    (942, 192, 996, 268, "both"),
    (954, 148, 984, 186, "both"),
]

CHARACTERS = [
    {
        "module": "PlayerMain",
        "comment": "Your player: head from main_player_sheet.png, navy team kit (numbers removed) from teammate7_sheet.png.",
        "head": ("main_player_sheet.png", MAIN_HEAD),
        "body": ("teammate7_sheet.png", TEMPLATE_BODY),
        "erase": ERASE_T7,
    },
    {
        "module": "Teammate7",
        "comment": "Teammate #7 cut from teammate7_sheet.png.",
        "head": ("teammate7_sheet.png", TEMPLATE_HEAD),
        "body": ("teammate7_sheet.png", TEMPLATE_BODY),
    },
    {
        "module": "Teammate28",
        "comment": "Teammate #28 cut from teammate28_sheet.png.",
        "head": ("teammate28_sheet.png", TEMPLATE_HEAD),
        "body": ("teammate28_sheet.png", TEMPLATE_BODY),
    },
    {
        "module": "Rival9",
        "comment": "Rival #9 cut from rival9_sheet.png.",
        "head": ("rival9_sheet.png", TEMPLATE_HEAD),
        "body": ("rival9_sheet.png", TEMPLATE_BODY),
    },
]


def erase(sheet: Image.Image, boxes):
    """Paints boxes over with a blend of the colours just left and right of them, row by row."""
    px = sheet.load()
    for x0, y0, x1, y1, side in boxes:
        for y in range(y0, y1):
            left = [px[x0 - k, y] for k in range(2, 6)]
            right = [px[x1 + k, y] for k in range(2, 6)]
            a = tuple(sum(c[i] for c in left) // len(left) for i in range(3))
            b = tuple(sum(c[i] for c in right) // len(right) for i in range(3))
            if side == "left":
                b = a
            elif side == "right":
                a = b
            for x in range(x0, x1):
                t = (x - x0) / max(1, x1 - x0 - 1)
                px[x, y] = tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def is_background(c) -> bool:
    r, g, b = c[:3]
    return 0.3 * r + 0.59 * g + 0.11 * b < 60 and b > g + 6


def clean_hand(im: Image.Image) -> Image.Image:
    """Hands are fists, so their boxes catch the dark purple backdrop at the corners: fill those
    pixels (below the wristband) with the row's skin colour."""
    im = im.copy()
    px = im.load()
    w, h = im.size
    for y in range(int(h * 0.3), h):
        skin = [px[x, y] for x in range(w) if not is_background(px[x, y])]
        if not skin:
            continue
        fill = tuple(sorted(c[i] for c in skin)[len(skin) // 2] for i in range(3))
        for x in range(w):
            if is_background(px[x, y]):
                px[x, y] = fill
    return im


def crop(sheet: Image.Image, box) -> Image.Image:
    im = sheet.crop(box)
    w, h = im.size
    scale = min(1, MAX_SIDE / max(w, h))
    if scale < 1:
        im = im.resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.LANCZOS)
    return im


def pack(im: Image.Image) -> str:
    """ImageLoader's format: u16 width, height, palette size, RGBA palette, LZ-coded indices."""
    q = im.convert("RGB").quantize(COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    palette = q.getpalette()[: COLORS * 3]
    used = len(q.getcolors(256))
    idx = bytes(q.get_flattened_data() if hasattr(q, "get_flattened_data") else q.getdata())
    w, h = q.size
    n = max(used, max(idx) + 1)
    out = bytearray()
    out += w.to_bytes(2, "little") + h.to_bytes(2, "little") + n.to_bytes(2, "little")
    for i in range(n):
        out += bytes(palette[i * 3: i * 3 + 3]) + b"\xff"
    literals = bytearray()

    def flush():
        while literals:
            chunk = literals[:128]
            out.append(len(chunk) - 1)
            out.extend(chunk)
            del literals[:128]

    table = {}
    i = 0
    while i < len(idx):
        best_len, best_off = 0, 0
        key = idx[i: i + 3]
        if len(key) == 3:
            for j in reversed(table.get(key, [])[-32:]):
                off = i - j
                if off > 65535:
                    continue
                length = 0
                while length < 130 and i + length < len(idx) and idx[j + length] == idx[i + length]:
                    length += 1
                if length > best_len:
                    best_len, best_off = length, off
        if best_len >= 3:
            flush()
            out.append(best_len + 125)
            out += best_off.to_bytes(2, "little")
            for k in range(best_len):
                table.setdefault(idx[i + k: i + k + 3], []).append(i + k)
            i += best_len
        else:
            literals.append(idx[i])
            table.setdefault(key, []).append(i)
            i += 1
    flush()
    return base64.b64encode(bytes(out)).decode()


def write_module(name: str, comment: str, images):
    lines = ["-- Generated by tools/assets/build_players.py. Do not edit by hand.", "-- " + comment, "return {"]
    for key, im in images.items():
        data = pack(im)
        lines.append(f'\t["{key}"] = [==[')
        lines += [data[k: k + 160] for k in range(0, len(data), 160)]
        lines.append("]==],")
    lines.append("}")
    with open(os.path.join(OUT, name + ".lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


# --- preview: the rig's front / back / left views with the textures on (studs from FigureBuilder)
RIG = [  # part, width (x), height, depth (z), centre x, centre y; the character's left is -X
    ("Head", 1.4, 1.25, 1.3, 0, 4.625), ("Hair", 1.5, 0.34, 1.42, 0, 5.365),
    ("UpperTorso", 2, 1.4, 1, 0, 3.3), ("LowerTorso", 2, 0.6, 1, 0, 2.3),
    ("RightUpperArm", 0.9, 1, 0.9, 1.45, 3.5), ("RightLowerArm", 0.85, 0.75, 0.85, 1.45, 2.625), ("RightHand", 0.95, 0.75, 0.95, 1.45, 1.875),
    ("LeftUpperArm", 0.9, 1, 0.9, -1.45, 3.5), ("LeftLowerArm", 0.85, 0.75, 0.85, -1.45, 2.625), ("LeftHand", 0.95, 0.75, 0.95, -1.45, 1.875),
    ("RightUpperLeg", 0.98, 1.05, 0.98, 0.5, 1.475), ("RightLowerLeg", 0.9, 0.6, 0.9, 0.5, 0.65),
    ("LeftUpperLeg", 0.98, 1.05, 0.98, -0.5, 1.475), ("LeftLowerLeg", 0.9, 0.6, 0.9, -0.5, 0.65),
]


def face_key(part: str, face: str) -> str:
    if part in ("Head", "Hair"):
        return part + face
    if part in ("UpperTorso", "LowerTorso"):
        return part + ("Side" if face in ("Left", "Right") else face)
    return part + ("Side" if face in ("Left", "Right") else face)


def preview(images, path):
    S = 60
    W, H = 3 * 4 * S + 40, int(6.2 * S)
    canvas = Image.new("RGB", (W, H), (24, 14, 40))
    for vi, view in enumerate(["Front", "Back", "Left"]):
        ox = vi * (4 * S + 20) + 2 * S
        for part, w, h, d, cx, cy in RIG:
            if view == "Left" and part.startswith("Right") and "Arm" not in part and "Hand" not in part:
                continue
            if view == "Left" and part.startswith("Right"):
                continue
            x = {"Front": -cx, "Back": cx, "Left": 0}[view]  # Front: the character's right on the left
            width = w if view != "Left" else d
            if view == "Left" and part.startswith("Left") and ("Arm" in part or "Hand" in part):
                x = 0
            key = face_key(part, view)
            im = images.get(key)
            if im is None:
                continue
            im = im.resize((max(1, int(width * S)), max(1, int(h * S))))
            canvas.paste(im, (int(ox + (x - width / 2) * S), int(H - 10 - (cy + h / 2) * S)))
    canvas.save(path)


def main():
    preview_dir = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    sheets = {}
    for ch in CHARACTERS:
        images = {}
        for sheet_name, boxes in (ch["head"], ch["body"]):
            cache_key = (sheet_name, tuple(ch.get("erase", [])) if boxes is TEMPLATE_BODY else ())
            if cache_key not in sheets:
                sheet = Image.open(os.path.join(SOURCE, sheet_name)).convert("RGB")
                if boxes is TEMPLATE_BODY and ch.get("erase"):
                    erase(sheet, ch["erase"])
                sheets[cache_key] = sheet
            for key, box in boxes.items():
                images[key] = crop(sheets[cache_key], box)
                if "Hand" in key:
                    images[key] = clean_hand(images[key])
        write_module(ch["module"], ch["comment"], images)
        print("wrote", ch["module"], len(images), "images")
        if preview_dir:
            preview(images, os.path.join(preview_dir, ch["module"] + ".png"))


if __name__ == "__main__":
    main()
