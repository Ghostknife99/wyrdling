#!/usr/bin/env python3
"""Build art/tiles/overworld/hd_atlas.png — 47-tile blob autotiles.

Samples Arthur's painted grass/path/water fills. Generates inner-corner
frames (and the rest of the 47-blob) so grass↔path and grass↔water coasts
are concave, not unique-tile stair-steps.

Does NOT overwrite Arthur's individual tile PNGs.
"""
from __future__ import annotations

import math
from collections import Counter
from pathlib import Path

from PIL import Image

N = 32
OW = Path("/workspace/wyrdling/art/tiles/overworld")
OUT = OW / "hd_atlas.png"

COLS = 16
PATH_ROW0 = 2
WATER_ROW0 = 5
WATER_PER_ROW = 5
WATER_FRAMES = 3
ROWS = 15

N_BIT, E_BIT, S_BIT, W_BIT = 1, 2, 4, 8
NE_BIT, SE_BIT, SW_BIT, NW_BIT = 16, 32, 64, 128

LANTERN_DIM = (0xC4, 0xA4, 0x5A, 255)
TIDE_4 = (0x4A, 0xB8, 0xA8, 255)


def lerp4(a, b, t):
    if len(a) == 3:
        a = a + (255,)
    if len(b) == 3:
        b = b + (255,)
    t = max(0.0, min(1.0, t))
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(4))


def hash01(x, y, seed=0):
    n = (x * 374761393 + y * 668265263 + seed * 1274126177) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177
    return ((n & 0xFFFFFFFF) % 10000) / 10000.0


def vnoise(x, y, seed, cell=8, period=N):
    gx, gy = x / cell, y / cell
    ix, iy = int(math.floor(gx)), int(math.floor(gy))
    fx, fy = gx - ix, gy - iy
    nlat = max(1, period // cell)

    def h(i, j):
        return hash01(i % nlat, j % nlat, seed)

    a, b, c, d = h(ix, iy), h(ix + 1, iy), h(ix, iy + 1), h(ix + 1, iy + 1)
    u = fx * fx * (3 - 2 * fx)
    v = fy * fy * (3 - 2 * fy)
    return a * (1 - u) * (1 - v) + b * u * (1 - v) + c * (1 - u) * v + d * u * v


def blend(a, b, t):
    if t <= 0:
        return a
    if t >= 1:
        return b
    return lerp4(a, b, t)


def edge_t(x, y, side):
    """1 = grass occupying that side of a PATH/WATER cell."""
    n = vnoise(x, y, 101, cell=4) * 5.0 - 2.5
    if side == "n":
        thresh = 11 + n
        return 1.0 if y < thresh else (0.0 if y > thresh + 1 else (thresh + 1 - y))
    if side == "s":
        thresh = 20 + n
        return 1.0 if y > thresh else (0.0 if y < thresh - 1 else (y - (thresh - 1)))
    if side == "w":
        thresh = 11 + n
        return 1.0 if x < thresh else (0.0 if x > thresh + 1 else (thresh + 1 - x))
    if side == "e":
        thresh = 20 + n
        return 1.0 if x > thresh else (0.0 if x < thresh - 1 else (x - (thresh - 1)))
    return 0.0


def inner_bite(x, y, corner):
    """Quarter-circle grass bite in a concave (inner) corner. 1 = grass."""
    n = vnoise(x, y, 109, cell=4) * 2.4 - 1.2
    r = 13.0 + n
    if corner == "ne":
        ox, oy = N - 0.5, 0.5
    elif corner == "nw":
        ox, oy = 0.5, 0.5
    elif corner == "se":
        ox, oy = N - 0.5, N - 0.5
    else:
        ox, oy = 0.5, N - 0.5
    d = math.hypot(x + 0.5 - ox, y + 0.5 - oy)
    if d >= r + 1.4:
        return 0.0
    if d <= r - 1.4:
        return 1.0
    return (r + 1.4 - d) / 2.8


def blob_masks():
    masks = []
    for card in range(16):
        allowed = []
        if (card & N_BIT) and (card & E_BIT):
            allowed.append(NE_BIT)
        if (card & E_BIT) and (card & S_BIT):
            allowed.append(SE_BIT)
        if (card & S_BIT) and (card & W_BIT):
            allowed.append(SW_BIT)
        if (card & W_BIT) and (card & N_BIT):
            allowed.append(NW_BIT)
        n = len(allowed)
        for sub in range(1 << n):
            m = card
            for i in range(n):
                if sub & (1 << i):
                    m |= allowed[i]
            masks.append(m)
    assert len(masks) == 47, len(masks)
    return masks


MASKS = blob_masks()


def grass_amt(x, y, mask):
    """0 = fully path/water, 1 = fully grass. Includes inner corners."""
    n = bool(mask & N_BIT)
    e = bool(mask & E_BIT)
    s = bool(mask & S_BIT)
    w = bool(mask & W_BIT)
    ne = bool(mask & NE_BIT)
    se = bool(mask & SE_BIT)
    sw = bool(mask & SW_BIT)
    nw = bool(mask & NW_BIT)
    g = 0.0
    if not n:
        g = max(g, edge_t(x, y, "n"))
    if not e:
        g = max(g, edge_t(x, y, "e"))
    if not s:
        g = max(g, edge_t(x, y, "s"))
    if not w:
        g = max(g, edge_t(x, y, "w"))
    if n and e and not ne:
        g = max(g, inner_bite(x, y, "ne"))
    if s and e and not se:
        g = max(g, inner_bite(x, y, "se"))
    if s and w and not sw:
        g = max(g, inner_bite(x, y, "sw"))
    if n and w and not nw:
        g = max(g, inner_bite(x, y, "nw"))
    return g


def load_rgba(name):
    p = OW / name
    if not p.exists():
        alt = OW.parent / name
        if alt.exists():
            p = alt
        else:
            raise FileNotFoundError(name)
    return Image.open(p).convert("RGBA")


def sample(im, x, y, ox=0, oy=0):
    w, h = im.size
    return im.getpixel(((x + ox) % w, (y + oy) % h))


def mix_blob(grass_im, other_im, mask, water=False, frame=0):
    im = Image.new("RGBA", (N, N))
    px = im.load()
    oy = frame * 5 if water else 0
    ox = frame * 3 if water else 0
    for y in range(N):
        for x in range(N):
            gcol = sample(grass_im, x, y)
            ocol = sample(other_im, x, y, ox=ox, oy=oy)
            t_grass = grass_amt(x, y, mask)
            col = blend(ocol, gcol, t_grass)
            if water and 0.22 < t_grass < 0.82:
                foam = vnoise(x, y + frame * 3, 13, cell=4)
                if foam > 0.52:
                    col = lerp4(col, TIDE_4, 0.38)
                    col = lerp4(col, LANTERN_DIM, 0.08)
            px[x, y] = col
    return im


def make_tallgrass_overlay(rustle=False):
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    px = im.load()
    for i in range(20):
        x0 = int(1 + hash01(i, 3, 9) * 29)
        h = int(12 + hash01(i, 5, 11) * 16)
        y1 = N - 1 - int(hash01(i, 7, 13) * 2)
        y0 = max(0, y1 - h)
        col = lerp4((0x2D, 0x4A, 0x28, 255), (0x5A, 0x8A, 0x42, 255), hash01(i, 1, 17))
        col = lerp4(col, (0x2A, 0x26, 0x22, 255), 0.12)
        dark = lerp4(col, (0x1A, 0x2A, 0x18, 255), 0.5)
        for y in range(y0, y1 + 1):
            sway = math.sin((y + i) * 0.45)
            if rustle:
                sway = math.sin((y + i) * 0.7 + 1.2) * 1.6
            xx = x0 + int(round(sway * (1.15 if rustle else 0.8)))
            if 0 <= xx < N:
                a = 230 if y > 8 else 150
                c = dark if (y + i) % 3 == 0 else col
                px[xx, y] = (c[0], c[1], c[2], a)
                if 0 <= xx + 1 < N and hash01(xx, y, 21) > 0.45:
                    px[xx + 1, y] = (col[0], col[1], col[2], int(a * 0.75))
        if 0 <= x0 < N and 0 <= y0 < N:
            seed = lerp4((0x8B, 0x5A, 0x2B, 255), (0x7A, 0xAA, 0x58, 255), 0.3)
            px[x0, y0] = seed
    return im


def paste(atlas, tile, tx, ty):
    atlas.alpha_composite(tile, (tx * N, ty * N))


def split_tree(tree):
    t = tree.convert("RGBA")
    if t.size != (64, 64):
        t = t.resize((64, 64), Image.Resampling.NEAREST)
    return {
        "nw": t.crop((0, 0, 32, 32)),
        "ne": t.crop((32, 0, 64, 32)),
        "sw": t.crop((0, 32, 32, 64)),
        "se": t.crop((32, 32, 64, 64)),
    }


def mean_color(im):
    acc = [0, 0, 0]
    n = 0
    for p in im.getdata():
        acc[0] += p[0]
        acc[1] += p[1]
        acc[2] += p[2]
        n += 1
    return tuple(int(round(c / n)) for c in acc)


def main():
    grass_im = load_rgba("grass.png")
    grass_alt_im = load_rgba("grass_alt.png")
    path_im = load_rgba("path.png")
    water_im = load_rgba("water.png")
    print("sampled grass", mean_color(grass_im), "path", mean_color(path_im), "water", mean_color(water_im))
    print("grass top", Counter(grass_im.getdata()).most_common(3))

    cliff_im = load_rgba("cliff.png")
    cliff_top_im = load_rgba("cliff_top.png")
    try:
        stairs_im = load_rgba("stairs.png")
    except FileNotFoundError:
        stairs_im = Image.new("RGBA", (N, N), (0, 0, 0, 0))

    atlas = Image.new("RGBA", (COLS * N, ROWS * N), (0, 0, 0, 0))
    paste(atlas, grass_im, 0, 0)
    paste(atlas, grass_alt_im, 1, 0)
    paste(atlas, cliff_im, 2, 0)
    paste(atlas, cliff_top_im, 3, 0)
    paste(atlas, stairs_im, 4, 0)
    paste(atlas, make_tallgrass_overlay(False), 5, 0)
    paste(atlas, make_tallgrass_overlay(True), 6, 0)
    for i, name in enumerate(
        ["fence_h", "fence_v", "fence_post", "fence_nw", "fence_ne", "fence_sw", "fence_se"]
    ):
        paste(atlas, load_rgba(f"{name}.png"), 7 + i, 0)

    q = split_tree(load_rgba("tree.png"))
    paste(atlas, q["nw"], 14, 0)
    paste(atlas, q["ne"], 15, 0)
    paste(atlas, q["sw"], 0, 1)
    paste(atlas, q["se"], 1, 1)

    for i, mask in enumerate(MASKS):
        tx, ty = i % COLS, PATH_ROW0 + i // COLS
        if mask == 255:
            tile = path_im
        else:
            tile = mix_blob(grass_im, path_im, mask, water=False)
        paste(atlas, tile, tx, ty)

    for i, mask in enumerate(MASKS):
        for f in range(WATER_FRAMES):
            tx = (i % WATER_PER_ROW) * WATER_FRAMES + f
            ty = WATER_ROW0 + i // WATER_PER_ROW
            if mask == 255:
                tile = Image.new("RGBA", (N, N))
                for y in range(N):
                    for x in range(N):
                        tile.putpixel((x, y), sample(water_im, x, y, ox=f * 3, oy=f * 5))
            else:
                tile = mix_blob(grass_im, water_im, mask, water=True, frame=f)
            paste(atlas, tile, tx, ty)

    OW.mkdir(parents=True, exist_ok=True)
    atlas.save(OUT)
    print(f"wrote {OUT} {atlas.size} masks={len(MASKS)}")

    # Preview: outer NE, inner NE, island, solid
    preview = Image.new("RGBA", (16 * N, 4 * N), (12, 11, 10, 255))
    for i in range(47):
        tx, ty = i % 16, i // 16
        src = atlas.crop((tx * N, (PATH_ROW0 + ty) * N, (tx + 1) * N, (PATH_ROW0 + ty + 1) * N))
        preview.paste(src, (tx * N, ty * N))
    prev_path = Path("/tmp/path_blob_preview.png")
    preview.save(prev_path)
    inner = [i for i, m in enumerate(MASKS) if (m & 15) == 15 and (m & NE_BIT) == 0]
    print("inner-NE-ish indices", inner[:8], "preview", prev_path)
    print("mask 255 idx", MASKS.index(255) if 255 in MASKS else None)


if __name__ == "__main__":
    main()
