#!/usr/bin/env python3
"""Original rift-wilds placeholder tiles for Wyrdling.

Invented outdoor tiles — moss-teal grass, lantern-dust dirt, rift water,
brass fence, mossy cliff. Not Pokémon / GBA rips. Skips files that already
exist so painted art is never overwritten.
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "art" / "tiles" / "wilds"

# Locked rift-wilds palette
GRASS_DK = (42, 74, 56, 255)      # #2a4a38
GRASS_LT = (61, 107, 74, 255)     # #3d6b4a
GRASS_MID = (50, 90, 64, 255)
GRASS_SH = (32, 56, 44, 255)
GRASS_HI = (78, 128, 92, 255)
TUFT = (46, 96, 68, 255)
TUFT_DK = (28, 52, 40, 255)

DIRT_DK = (138, 106, 69, 255)     # #8a6a45
DIRT_LT = (196, 163, 90, 255)     # #c4a35a
DIRT_MID = (166, 128, 78, 255)
DIRT_SH = (108, 80, 50, 255)
DIRT_PEB = (184, 148, 96, 255)

WATER = (21, 56, 72, 255)         # #153848
WATER_DK = (10, 32, 44, 255)
WATER_WAVE = (16, 46, 60, 255)
WATER_HI = (32, 78, 96, 255)
WATER_DEEP = (8, 24, 34, 255)

SHORE_EDGE = (8, 20, 28, 255)
SHORE_LIP = (18, 40, 50, 255)
SHORE_HI = (48, 88, 100, 180)

BRASS = (176, 141, 87, 255)       # #b08d57
BRASS_DK = (118, 88, 46, 255)
BRASS_HI = (214, 182, 122, 255)
BRASS_CAP = (232, 200, 114, 255)

GOLD = (232, 200, 114, 255)       # #E8C872
GOLD_DK = (168, 130, 52, 255)

CLIFF_DK = (36, 52, 40, 255)
CLIFF_MID = (54, 74, 52, 255)
CLIFF_MOSS = (42, 74, 56, 255)
CLIFF_LIP = (72, 108, 78, 255)
CLIFF_SH = (22, 34, 26, 255)
CLIFF_FACE = (48, 64, 46, 255)

TRUNK = (96, 66, 40, 255)
TRUNK_DK = (62, 40, 26, 255)
TRUNK_HI = (128, 92, 56, 255)
CANOPY_DK = (26, 54, 38, 255)
CANOPY = (40, 82, 54, 255)
CANOPY_LT = (68, 118, 78, 255)
CANOPY_MOSS = (52, 96, 64, 255)


def rgba(size, color=(0, 0, 0, 0)) -> Image.Image:
    return Image.new("RGBA", size, color)


def hsh(x: int, y: int, s: int = 0) -> int:
    n = (x * 374761393 + y * 668265263 + s * 1274126177) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177
    return n & 0xFFFFFFFF


def put(img: Image.Image, x: int, y: int, color) -> None:
    w, h = img.size
    img.putpixel((x % w, y % h), color)


def save_if_missing(img: Image.Image, name: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    if path.exists():
        print("keep existing", path.relative_to(ROOT), img.size)
        return
    img.save(path, "PNG")
    print("wrote", path.relative_to(ROOT), img.size)


def grass_tile(alt: bool = False) -> Image.Image:
    """Seamless moss-teal with wrapping V-tufts."""
    img = rgba((32, 32), GRASS_DK if not alt else (40, 78, 58, 255))
    seed = 11 if alt else 3
    base_a = GRASS_DK if not alt else (38, 72, 54, 255)
    base_b = GRASS_LT if not alt else (58, 104, 72, 255)
    for y in range(32):
        for x in range(32):
            n = hsh(x, y, seed)
            # low-freq wrap-friendly checker via sin of wrapped coords
            wx = math.sin((x / 32.0) * math.tau) + math.cos((y / 32.0) * math.tau)
            if (n & 7) == 0:
                put(img, x, y, base_b)
            elif (n & 15) == 1:
                put(img, x, y, GRASS_SH)
            elif wx > 0.6 and (n & 3) == 0:
                put(img, x, y, GRASS_MID)
            else:
                put(img, x, y, base_a)
    # wrapping V tufts — GBA-style texture, original placement
    tufts = (
        (4, 6), (18, 3), (28, 10), (10, 16), (22, 20),
        (6, 26), (16, 28), (30, 22), (2, 14), (12, 8),
    )
    if alt:
        tufts = (
            (8, 4), (20, 8), (2, 12), (14, 14), (26, 18),
            (10, 24), (22, 28), (30, 6), (16, 20), (4, 30),
        )
    for tx, ty in tufts:
        put(img, tx, ty, TUFT_DK)
        put(img, tx - 1, ty + 1, TUFT)
        put(img, tx + 1, ty + 1, TUFT)
        put(img, tx, ty + 2, GRASS_HI)
        put(img, tx - 2, ty + 2, TUFT_DK)
        put(img, tx + 2, ty + 2, TUFT_DK)
    return img


def dirt_tile() -> Image.Image:
    img = rgba((32, 32), DIRT_DK)
    for y in range(32):
        for x in range(32):
            n = hsh(x, y, 21)
            v = (n >> 8) & 3
            if v == 0:
                put(img, x, y, DIRT_MID)
            elif v == 1 and (n & 15) == 0:
                put(img, x, y, DIRT_LT)
            elif (n & 31) == 2:
                put(img, x, y, DIRT_SH)
            else:
                put(img, x, y, DIRT_DK)
    # wrapping pebbles / lantern-dust flecks
    pebbles = ((5, 7), (14, 4), (24, 9), (8, 18), (20, 16), (28, 22), (3, 26), (16, 28), (30, 14), (11, 12))
    for px, py in pebbles:
        put(img, px, py, DIRT_PEB)
        put(img, px + 1, py, DIRT_LT)
        put(img, px, py + 1, DIRT_SH)
    # faint wrap-safe scuff lines
    for x in range(32):
        if hsh(x, 11, 4) & 3:
            put(img, x, 11, DIRT_MID)
        if hsh(x, 23, 5) & 3:
            put(img, x, 23, DIRT_MID)
    return img


def water_tile() -> Image.Image:
    img = rgba((32, 32), WATER)
    for y in range(32):
        for x in range(32):
            # two wrapping wave bands
            wave = math.sin((x / 16.0) * math.tau + (y / 8.0) * 0.7)
            wave2 = math.sin((x / 32.0) * math.tau + (y / 16.0) * math.tau)
            if wave > 0.55:
                put(img, x, y, WATER_WAVE)
            elif wave2 < -0.65:
                put(img, x, y, WATER_DK)
            elif (hsh(x, y, 9) & 31) == 0:
                put(img, x, y, WATER_HI)
            else:
                put(img, x, y, WATER)
            # darker trough every 8 rows, wrapping
            if (y + int(2 * math.sin(x * math.tau / 16.0))) % 8 == 0:
                put(img, x, y, WATER_DEEP)
    return img


def shore_tile(side: str) -> Image.Image:
    """Transparent overlay: dark drop-off ledge on the water-facing edge."""
    img = rgba((32, 32))
    d = ImageDraw.Draw(img)
    if side == "n":
        d.rectangle([0, 0, 31, 1], fill=SHORE_EDGE)
        d.rectangle([0, 2, 31, 3], fill=SHORE_LIP)
        d.line([(0, 4), (31, 4)], fill=SHORE_HI)
        for x in (4, 12, 19, 27):
            img.putpixel((x, 3), WATER_DEEP)
    elif side == "s":
        d.line([(0, 27), (31, 27)], fill=SHORE_HI)
        d.rectangle([0, 28, 31, 29], fill=SHORE_LIP)
        d.rectangle([0, 30, 31, 31], fill=SHORE_EDGE)
        for x in (6, 15, 24):
            img.putpixel((x, 29), WATER_DEEP)
    elif side == "w":
        d.rectangle([0, 0, 1, 31], fill=SHORE_EDGE)
        d.rectangle([2, 0, 3, 31], fill=SHORE_LIP)
        d.line([(4, 0), (4, 31)], fill=SHORE_HI)
    elif side == "e":
        d.line([(27, 0), (27, 31)], fill=SHORE_HI)
        d.rectangle([28, 0, 29, 31], fill=SHORE_LIP)
        d.rectangle([30, 0, 31, 31], fill=SHORE_EDGE)
    return img


def tall_grass_tile() -> Image.Image:
    """Blades concentrated mid/low so they hide feet; top stays airy."""
    img = rgba((32, 32))
    d = ImageDraw.Draw(img)
    clusters = [
        (3, 28, 18, GRASS_SH),
        (8, 30, 22, GRASS_DK),
        (13, 29, 24, GRASS_LT),
        (18, 31, 20, GRASS_MID),
        (23, 28, 23, GRASS_LT),
        (28, 30, 19, GRASS_DK),
        (5, 26, 14, TUFT),
        (16, 27, 16, GRASS_HI),
        (25, 26, 15, TUFT_DK),
        (10, 24, 12, CANOPY_LT),
    ]
    for cx, base, height, col in clusters:
        tip_y = max(2, base - height)
        # blade as a thin triangle
        d.polygon([(cx, base), (cx - 2, base - 4), (cx, tip_y), (cx + 2, base - 4)], fill=col)
        d.line([(cx, base), (cx, tip_y)], fill=TUFT_DK)
        # secondary shorter blade
        d.polygon(
            [(cx + 3, base), (cx + 2, base - 3), (cx + 3, tip_y + 6), (cx + 4, base - 3)],
            fill=GRASS_DK,
        )
    # denser skirt at the bottom so feet vanish
    for x in range(32):
        n = hsh(x, 30, 17)
        for y in range(20, 32):
            if (n + y) & 3 != 0:
                a = 220 if y > 24 else 160
                c = GRASS_LT if (x + y) & 1 else GRASS_DK
                px = img.getpixel((x, y))
                if px[3] == 0:
                    img.putpixel((x, y), (c[0], c[1], c[2], a))
    return img


def fence_post() -> Image.Image:
    img = rgba((32, 32))
    d = ImageDraw.Draw(img)
    # brass stake, slightly 3/4
    d.rectangle([13, 12, 18, 30], fill=BRASS_DK)
    d.rectangle([14, 12, 17, 29], fill=BRASS)
    d.line([(14, 12), (14, 29)], fill=BRASS_HI)
    d.ellipse([12, 8, 19, 16], fill=BRASS)
    d.ellipse([13, 9, 18, 14], fill=BRASS_HI)
    d.point((16, 11), GOLD)
    d.rectangle([13, 29, 18, 31], fill=BRASS_DK)
    return img


def fence_h() -> Image.Image:
    """Horizontal rail only — tiles left/right. Posts drawn separately."""
    img = rgba((32, 32))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 16, 31, 20], fill=BRASS_DK)
    d.rectangle([0, 17, 31, 19], fill=BRASS)
    d.line([(0, 17), (31, 17)], fill=BRASS_HI)
    # ring rivets
    for x in (4, 16, 27):
        d.ellipse([x - 1, 16, x + 2, 21], fill=BRASS_HI)
        d.point((x, 18), BRASS_DK)
    return img


def fence_v() -> Image.Image:
    img = rgba((32, 32))
    d = ImageDraw.Draw(img)
    d.rectangle([14, 0, 18, 31], fill=BRASS_DK)
    d.rectangle([15, 0, 17, 31], fill=BRASS)
    d.line([(15, 0), (15, 31)], fill=BRASS_HI)
    for y in (6, 16, 26):
        d.rectangle([13, y, 19, y + 2], fill=BRASS)
    return img


def cliff_tile() -> Image.Image:
    """Mossy 3/4 bank, not grey brick."""
    img = rgba((32, 32), CLIFF_DK)
    d = ImageDraw.Draw(img)
    # top lip (walkable-looking moss rim)
    d.rectangle([0, 0, 31, 6], fill=CLIFF_MOSS)
    d.line([(0, 6), (31, 6)], fill=CLIFF_LIP)
    d.line([(0, 7), (31, 7)], fill=CLIFF_SH)
    # face with moss streaks, not a brick grid
    for y in range(8, 32):
        for x in range(32):
            n = hsh(x, y, 33)
            if (n & 7) == 0:
                put(img, x, y, CLIFF_MOSS)
            elif (n & 7) == 1:
                put(img, x, y, CLIFF_MID)
            elif (n & 15) == 2:
                put(img, x, y, CLIFF_FACE)
            else:
                put(img, x, y, CLIFF_DK)
    # diagonal rock facets
    d.polygon([(2, 10), (14, 9), (10, 30), (0, 31)], fill=CLIFF_FACE)
    d.polygon([(18, 11), (31, 8), (31, 31), (20, 31)], fill=CLIFF_MID)
    d.line([(8, 12), (6, 30)], fill=CLIFF_SH)
    d.line([(24, 12), (26, 30)], fill=CLIFF_SH)
    # moss patches
    d.ellipse([4, 16, 12, 22], fill=GRASS_DK)
    d.ellipse([20, 20, 29, 26], fill=CLIFF_MOSS)
    return img


def stairs_tile() -> Image.Image:
    """Gold rift-gate set in dirt, not a brick staircase."""
    img = dirt_tile()
    d = ImageDraw.Draw(img)
    # dark well
    d.ellipse([4, 6, 27, 28], fill=(18, 22, 28, 255))
    d.ellipse([6, 8, 25, 26], fill=(28, 18, 40, 255))
    # concentric gold rings
    d.ellipse([7, 9, 24, 25], outline=GOLD_DK, width=2)
    d.ellipse([9, 11, 22, 23], outline=GOLD, width=1)
    d.ellipse([13, 14, 18, 19], fill=GOLD)
    d.ellipse([14, 15, 17, 18], fill=(255, 236, 170, 255))
    # corner chevrons
    d.polygon([(16, 4), (18, 8), (14, 8)], fill=GOLD)
    return img


def tree_tile() -> Image.Image:
    """32x64 lantern-oak: round two-lobe canopy, crooked trunk. Not a pine."""
    img = rgba((32, 64))
    d = ImageDraw.Draw(img)
    # trunk — crooked, mossy, bottom 32
    d.polygon([(15, 36), (13, 50), (12, 62), (19, 62), (20, 48), (18, 36)], fill=TRUNK_DK)
    d.polygon([(16, 36), (15, 50), (14, 61), (17, 61), (19, 46), (17, 36)], fill=TRUNK)
    d.line([(16, 38), (15, 60)], fill=TRUNK_HI)
    d.rectangle([13, 60, 20, 63], fill=TRUNK_DK)
    # moss on trunk
    d.point((15, 52), CANOPY)
    d.point((17, 55), CANOPY_MOSS)
    # canopy — two lobes + a lower skirt (oak/cloud, not triangle)
    lobes = [
        (CANOPY_DK, [(-1, 8), (31, 8), (32, 28), (16, 36), (0, 28)]),
        (CANOPY, [(2, 6), (18, 2), (30, 10), (28, 26), (8, 28), (1, 18)]),
        (CANOPY_MOSS, [(4, 12), (16, 6), (26, 14), (22, 26), (8, 24)]),
        (CANOPY_LT, [(8, 10), (16, 8), (22, 14), (18, 20), (10, 18)]),
    ]
    d.ellipse([1, 4, 22, 30], fill=CANOPY_DK)
    d.ellipse([10, 2, 31, 28], fill=CANOPY_DK)
    d.ellipse([4, 8, 28, 34], fill=CANOPY)
    d.ellipse([3, 6, 20, 26], fill=CANOPY_MOSS)
    d.ellipse([14, 5, 29, 24], fill=CANOPY)
    d.ellipse([8, 10, 18, 20], fill=CANOPY_LT)
    d.ellipse([18, 12, 26, 20], fill=CANOPY_LT)
    # hanging lantern-fruit (gold motes, original)
    for cx, cy in ((8, 30), (22, 31), (15, 33)):
        d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=GOLD)
        d.line([(cx, cy - 4), (cx, cy - 2)], fill=TRUNK)
        d.point((cx, cy), (255, 236, 170, 255))
    # a few leaf holes so it doesn't read as a blob stamp
    d.point((10, 16), CANOPY_DK)
    d.point((24, 14), CANOPY_DK)
    return img


def main() -> None:
    save_if_missing(grass_tile(False), "grass.png")
    save_if_missing(grass_tile(True), "grass_alt.png")
    save_if_missing(dirt_tile(), "dirt.png")
    save_if_missing(water_tile(), "water.png")
    for s in ("n", "e", "s", "w"):
        save_if_missing(shore_tile(s), f"shore_{s}.png")
    save_if_missing(tall_grass_tile(), "tall_grass.png")
    save_if_missing(fence_h(), "fence_h.png")
    save_if_missing(fence_v(), "fence_v.png")
    save_if_missing(fence_post(), "fence_post.png")
    save_if_missing(tree_tile(), "tree.png")
    save_if_missing(cliff_tile(), "cliff.png")
    save_if_missing(stairs_tile(), "stairs.png")


if __name__ == "__main__":
    main()
