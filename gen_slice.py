#!/usr/bin/env python3
"""Wyrdling first-slice original pixel-art generator.
Folklore / fractured-reality. No Nintendo IP. Direct RGBA (no magenta).
"""
from __future__ import annotations

import math
import os
from collections import defaultdict

from PIL import Image, ImageDraw

OUT = "/workspace/wyrdling/first-slice"
os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------------------
# Palettes
# ---------------------------------------------------------------------------
def C(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


# Shared dungeon / lantern
LANTERN = C("FFE566")
LANTERN_CORE = C("FFF8DC")
LANTERN_DIM = C("C4A45A")
LANTERN_AURA = C("F5E6A3", 70)
UMBER = C("3A2A1A")
UMBER_MID = C("5A4030")
UMBER_HI = C("7A5A40")
STONE_0 = C("1A1816")
STONE_1 = C("2A2622")
STONE_2 = C("3A3630")
STONE_3 = C("4A463E")
STONE_4 = C("5C564C")
STONE_5 = C("6E675A")
MORTAR = C("241E18")
WARM = C("6B5428")
BRONZE = C("8A6A38")
BRONZE_HI = C("C4A45A")
PARCHMENT = C("E8D5A3")
INK = C("120E0C")

# Wisp
WISP_CORE = C("FFF8DC")
WISP_GOLD = C("FFE566")
WISP_GOLD2 = C("D4B84A")
WISP_BLUE = C("C8E8F8")
WISP_BLUE2 = C("6BB0D4")
WISP_BLUE3 = C("3A7090")
WISP_OUT = C("2A3040")
WISP_GLOW = C("F5E6A3", 55)

# Iron
IRON_0 = C("1E2228")
IRON_1 = C("2A3038")
IRON_2 = C("4A5560")
IRON_3 = C("6A7580")
IRON_4 = C("8A94A0")
RUST_0 = C("6B3010")
RUST_1 = C("8B4513")
RUST_2 = C("A0522D")
RUST_3 = C("C07040")
IRON_OUT = C("14161A")

# Bloom
BLOOM_0 = C("1A2A18")
BLOOM_1 = C("2D4A28")
BLOOM_2 = C("3D6B35")
BLOOM_3 = C("5A8A42")
BLOOM_4 = C("7AAA58")
SEED_0 = C("4A3018")
SEED_1 = C("6B4423")
SEED_2 = C("8B5A2B")
SEED_3 = C("A87840")
BLOOM_OUT = C("12180E")

# Dusk
DUSK_0 = C("0A0614")
DUSK_1 = C("1A0A28")
DUSK_2 = C("2D1A40")
DUSK_3 = C("4A2A68")
DUSK_4 = C("6A5080")
DUSK_5 = C("8A70A0")
BONE_0 = C("8A7A68")
BONE_1 = C("C8B8A0")
BONE_2 = C("E0D4C0")
DUSK_OUT = C("080510")
FOG = C("6A5080", 80)

# Tide
TIDE_0 = C("061818")
TIDE_1 = C("0A3A40")
TIDE_2 = C("1A5A58")
TIDE_3 = C("2A7A70")
TIDE_4 = C("4AB8A8")
TIDE_5 = C("7AD4C8")
TIDE_TEETH = C("E8E0D0")
TIDE_OUT = C("041012")

# Player
CLOAK_0 = C("241810")
CLOAK_1 = C("3A2A1A")
CLOAK_2 = C("5A4030")
CLOAK_3 = C("7A5A40")
SKIN_0 = C("6A5040")
SKIN_1 = C("C4A882")
SKIN_2 = C("D4BC96")
BOOT_0 = C("1A1410")
BOOT_1 = C("2A2018")
STAFF = C("3A2818")
STAFF_HI = C("5A4030")
PLAYER_OUT = C("100C0A")


# ---------------------------------------------------------------------------
# Canvas
# ---------------------------------------------------------------------------
class Spr:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.px = self.im.load()

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[x, y]
        return (0, 0, 0, 0)

    def p(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            if c is None:
                return
            if len(c) == 3:
                c = (c[0], c[1], c[2], 255)
            a = c[3]
            if a <= 0:
                return
            if a >= 255:
                self.px[x, y] = c
            else:
                dst = self.px[x, y]
                da = dst[3] / 255.0
                sa = a / 255.0
                out_a = sa + da * (1 - sa)
                if out_a <= 0:
                    return
                def mix(s, d):
                    return int(round((s * sa + d * da * (1 - sa)) / out_a))
                self.px[x, y] = (
                    mix(c[0], dst[0]),
                    mix(c[1], dst[1]),
                    mix(c[2], dst[2]),
                    int(round(out_a * 255)),
                )

    def pset(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            if len(c) == 3:
                c = (c[0], c[1], c[2], 255)
            self.px[x, y] = c

    def disc(self, cx, cy, r, c):
        r = max(r, 0)
        r2 = (r + 0.45) ** 2
        for y in range(int(math.floor(cy - r)), int(math.ceil(cy + r)) + 1):
            for x in range(int(math.floor(cx - r)), int(math.ceil(cx + r)) + 1):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r2:
                    self.p(x, y, c)

    def ellipse(self, cx, cy, rx, ry, c):
        rx, ry = max(rx, 0.5), max(ry, 0.5)
        for y in range(int(math.floor(cy - ry)), int(math.ceil(cy + ry)) + 1):
            for x in range(int(math.floor(cx - rx)), int(math.ceil(cx + rx)) + 1):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.02:
                    self.p(x, y, c)

    def ellipsoid(self, cx, cy, rx, ry, mid, shadow, highlight, light=(-0.45, -0.75), steps=5):
        rx, ry = max(rx, 0.6), max(ry, 0.6)
        lx, ly, lz = light[0], light[1], 0.55
        ln = math.sqrt(lx * lx + ly * ly + lz * lz)
        lx, ly, lz = lx / ln, ly / ln, lz / ln
        for y in range(int(math.floor(cy - ry)), int(math.ceil(cy + ry)) + 1):
            for x in range(int(math.floor(cx - rx)), int(math.ceil(cx + rx)) + 1):
                nx = (x - cx) / rx
                ny = (y - cy) / ry
                n2 = nx * nx + ny * ny
                if n2 <= 1.0:
                    nz = math.sqrt(max(0.0, 1.0 - n2))
                    ndot = nx * lx + ny * ly + nz * lz
                    t = max(0.0, min(1.0, (ndot + 0.15) / 1.15))
                    t = round(t * (steps - 1)) / (steps - 1)
                    if t < 0.5:
                        u = t / 0.5
                        col = lerp(shadow, mid, u)
                    else:
                        u = (t - 0.5) / 0.5
                        col = lerp(mid, highlight, u)
                    self.p(x, y, col)

    def line(self, x0, y0, x1, y1, c, w=1):
        x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
        dx, dy = abs(x1 - x0), abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx - dy
        r = max(0, (w - 1) / 2)
        while True:
            if w <= 1:
                self.p(x0, y0, c)
            else:
                self.disc(x0, y0, r, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 > -dy:
                err -= dy
                x0 += sx
            if e2 < dx:
                err += dx
                y0 += sy

    def poly(self, pts, c):
        if len(pts) < 3:
            return
        # bbox scanline
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        miny, maxy = int(math.floor(min(ys))), int(math.ceil(max(ys)))
        n = len(pts)
        for y in range(miny, maxy + 1):
            nodes = []
            j = n - 1
            for i in range(n):
                yi, yj = pts[i][1], pts[j][1]
                xi, xj = pts[i][0], pts[j][0]
                if (yi < y and yj >= y) or (yj < y and yi >= y):
                    nodes.append(xi + (y - yi) / (yj - yi + 1e-9) * (xj - xi))
                j = i
            nodes.sort()
            for k in range(0, len(nodes) - 1, 2):
                x0 = int(math.ceil(nodes[k]))
                x1 = int(math.floor(nodes[k + 1]))
                for x in range(x0, x1 + 1):
                    self.p(x, y, c)

    def rect(self, x, y, w, h, c):
        for yy in range(int(y), int(y + h)):
            for xx in range(int(x), int(x + w)):
                self.p(xx, yy, c)

    def outline(self, color, expand=True):
        """1px dark outline. expand=True grows silhouette outward."""
        opaque = []
        for y in range(self.h):
            for x in range(self.w):
                if self.px[x, y][3] >= 180:
                    opaque.append((x, y))
        if not opaque:
            return
        if expand:
            extra = []
            for x, y in opaque:
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h:
                        if self.px[nx, ny][3] < 80:
                            extra.append((nx, ny))
            for x, y in extra:
                self.pset(x, y, color)
        else:
            for x, y in opaque:
                edge = False
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < self.w and 0 <= ny < self.h) or self.px[nx, ny][3] < 80:
                        edge = True
                        break
                if edge:
                    self.pset(x, y, color)

    def glow(self, color, radius=3, thresh=180):
        seeds = []
        for y in range(self.h):
            for x in range(self.w):
                if self.px[x, y][3] >= thresh:
                    seeds.append((x, y))
        if not seeds:
            return
        # cheap distance: dilate
        glowmap = [[0] * self.w for _ in range(self.h)]
        for x, y in seeds:
            glowmap[y][x] = radius + 1
        for r in range(radius, 0, -1):
            for y in range(self.h):
                for x in range(self.w):
                    if glowmap[y][x] >= r + 1:
                        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                            nx, ny = x + dx, y + dy
                            if 0 <= nx < self.w and 0 <= ny < self.h:
                                if glowmap[ny][nx] < r:
                                    glowmap[ny][nx] = r
        cr, cg, cb, ca = color
        for y in range(self.h):
            for x in range(self.w):
                g = glowmap[y][x]
                if g > 0 and self.px[x, y][3] < 180:
                    t = g / (radius + 1)
                    a = int(ca * t * t)
                    if a > 8:
                        self.p(x, y, (cr, cg, cb, a))

    def ground_shadow(self, cx, cy, rx, ry, a=70):
        self.ellipse(cx, cy, rx, ry, C("000000", a))

    def save(self, path):
        self.im.save(path, "PNG")
        return self.im


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(4 if len(a) > 3 else 3)) + (
        () if len(a) == 4 else ((255,) if len(a) == 3 else ())
    )


def lerp4(a, b, t):
    if len(a) == 3:
        a = a + (255,)
    if len(b) == 3:
        b = b + (255,)
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(4))


def hash01(x, y, seed=0):
    n = (x * 374761393 + y * 668265263 + seed * 1274126177) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177
    return ((n & 0xFFFFFFFF) % 10000) / 10000.0


def crop_center(im: Image.Image, size: int, pad: int = 3) -> Image.Image:
    """Crop to opaque bbox, pad, NEAREST-scale to fit, center on canvas."""
    if im.mode != "RGBA":
        im = im.convert("RGBA")
    bbox = im.getbbox()
    if not bbox:
        return Image.new("RGBA", (size, size), (0, 0, 0, 0))
    subject = im.crop(bbox)
    sw, sh = subject.size
    inner = size - pad * 2
    if inner < 1:
        inner = size
        pad = 0
    scale = min(inner / sw, inner / sh)
    nw = max(1, int(round(sw * scale)))
    nh = max(1, int(round(sh * scale)))
    # Keep native if already fits; only NEAREST-scale when needed
    if (nw, nh) != (sw, sh):
        subject = subject.resize((nw, nh), Image.NEAREST)
        sw, sh = nw, nh
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    x = (size - sw) // 2
    y = (size - sh) // 2
    canvas.alpha_composite(subject, (x, y))
    return canvas


def save_sprite(spr: Spr, name: str, size: int, pad: int = 3):
    path = os.path.join(OUT, name)
    img = crop_center(spr.im, size, pad=pad)
    img.save(path, "PNG")
    return path, img


# ---------------------------------------------------------------------------
# Pixel font (5x7) + title font (7x11)
# ---------------------------------------------------------------------------
F5 = {
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
    "I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
    "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "W": ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
    "a": ["00000", "01110", "00001", "01111", "10001", "10001", "01111"],
    "d": ["00001", "00001", "00001", "01111", "10001", "10001", "01111"],
    "e": ["00000", "01110", "10001", "11111", "10000", "10001", "01110"],
    "g": ["00000", "01111", "10001", "10001", "01111", "00001", "01110"],
    "i": ["00100", "00000", "01100", "00100", "00100", "00100", "01110"],
    "k": ["10000", "10000", "10010", "10100", "11000", "10100", "10010"],
    "l": ["01100", "00100", "00100", "00100", "00100", "00100", "01110"],
    "n": ["00000", "11110", "10001", "10001", "10001", "10001", "10001"],
    "p": ["00000", "11110", "10001", "10001", "11110", "10000", "10000"],
    "r": ["00000", "10110", "11001", "10000", "10000", "10000", "10000"],
    "t": ["00100", "00100", "01110", "00100", "00100", "00100", "00010"],
    "u": ["00000", "10001", "10001", "10001", "10001", "10001", "01111"],
    "w": ["00000", "10001", "10001", "10101", "10101", "01010", "01010"],
    "y": ["00000", "10001", "10001", "01111", "00001", "00001", "01110"],
    " ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
}

# 7x11 title caps + lowercase for "Wyrdling"
F7 = {
    "W": [
        "1000001",
        "1000001",
        "1000001",
        "1001001",
        "1001001",
        "1001001",
        "1010101",
        "1010101",
        "0100010",
        "0100010",
        "0100010",
    ],
    "y": [
        "0000000",
        "0000000",
        "1000001",
        "1000001",
        "0100010",
        "0010100",
        "0001000",
        "0001000",
        "0001000",
        "0010000",
        "1100000",
    ],
    "r": [
        "0000000",
        "0000000",
        "1011100",
        "1100010",
        "1000000",
        "1000000",
        "1000000",
        "1000000",
        "1000000",
        "1000000",
        "1000000",
    ],
    "d": [
        "0000001",
        "0000001",
        "0000001",
        "0011111",
        "0100001",
        "1000001",
        "1000001",
        "1000001",
        "1000001",
        "0100001",
        "0011111",
    ],
    "l": [
        "0110000",
        "0010000",
        "0010000",
        "0010000",
        "0010000",
        "0010000",
        "0010000",
        "0010000",
        "0010000",
        "0010000",
        "0001110",
    ],
    "i": [
        "0010000",
        "0000000",
        "0110000",
        "0010000",
        "0010000",
        "0010000",
        "0010000",
        "0010000",
        "0010000",
        "0010000",
        "0111000",
    ],
    "n": [
        "0000000",
        "0000000",
        "1111100",
        "1000010",
        "1000010",
        "1000010",
        "1000010",
        "1000010",
        "1000010",
        "1000010",
        "1000010",
    ],
    "g": [
        "0000000",
        "0000000",
        "0011110",
        "0100001",
        "1000001",
        "1000001",
        "0100001",
        "0011111",
        "0000001",
        "0100001",
        "0011110",
    ],
}


def blit_font(spr: Spr, text, ox, oy, font, color, scale=1, shadow=None, tracking=1):
    x = ox
    gw = len(next(iter(font.values()))[0])
    gh = len(next(iter(font.values())))
    for ch in text:
        glyph = font.get(ch, font.get(" "))
        if glyph is None:
            x += (gw + tracking) * scale
            continue
        if shadow:
            for row, bits in enumerate(glyph):
                for col, bit in enumerate(bits):
                    if bit == "1":
                        for sy in range(scale):
                            for sx in range(scale):
                                spr.p(x + col * scale + sx + 1, oy + row * scale + sy + 1, shadow)
        for row, bits in enumerate(glyph):
            for col, bit in enumerate(bits):
                if bit == "1":
                    for sy in range(scale):
                        for sx in range(scale):
                            spr.p(x + col * scale + sx, oy + row * scale + sy, color)
        x += (gw + tracking) * scale
    return x


def text_width(text, font, scale=1, tracking=1):
    gw = len(next(iter(font.values()))[0])
    n = len(text)
    return n * (gw + tracking) * scale - tracking * scale


# ---------------------------------------------------------------------------
# STYLE FRAME (mood board, 256x256)
# ---------------------------------------------------------------------------
def make_style_frame():
    s = Spr(256, 256)
    # deep dungeon fill
    for y in range(256):
        for x in range(256):
            n = hash01(x, y, 3)
            v = 18 + int(n * 10)
            # vignette + lantern warmth toward center-upper
            dx, dy = (x - 128) / 128, (y - 90) / 160
            d = math.sqrt(dx * dx + dy * dy)
            warm = max(0, 1 - d)
            r = int(v + warm * 28)
            g = int(v * 0.9 + warm * 18)
            b = int(v * 0.75 + warm * 6)
            s.pset(x, y, (min(255, r), min(255, g), min(255, b), 255))

    # stone wall band at top
    for y in range(0, 78):
        course = y // 13
        for x in range(256):
            ox = (x + (course % 2) * 18) % 36
            n = hash01(x // 2, y // 2, 11 + course)
            grout = (ox < 2) or (y % 13 == 0) or (y % 13 == 12)
            if grout:
                s.pset(x, y, MORTAR)
            else:
                base = lerp4(STONE_1, STONE_3, 0.3 + n * 0.5)
                # lantern wash from below
                wash = max(0, (y - 50) / 28)
                col = lerp4(base, (80, 64, 36, 255), wash * 0.35)
                s.pset(x, y, col)

    # floor flagstones
    for y in range(78, 256):
        for x in range(256):
            tx, ty = (x + (y // 22) * 8) % 28, y % 22
            n = hash01(x // 3, y // 3, 21)
            grout = tx < 2 or ty < 2
            if grout:
                s.pset(x, y, lerp4(MORTAR, C("3A2A14"), 0.2))
            else:
                base = lerp4(STONE_1, STONE_4, n)
                # lantern pool at (128, 120)
                d = math.sqrt((x - 128) ** 2 + (y - 118) ** 2)
                wash = max(0, 1 - d / 90)
                col = lerp4(base, (90, 72, 40, 255), wash * 0.45)
                # cooler violet in corners
                if d > 100:
                    col = lerp4(col, DUSK_2, 0.15)
                s.pset(x, y, col)

    # hanging lantern
    s.line(128, 0, 128, 86, C("2A2018"), 2)
    s.ellipse(128, 98, 16, 18, UMBER)
    s.ellipse(128, 98, 12, 14, LANTERN_DIM)
    s.ellipse(128, 96, 8, 9, LANTERN)
    s.ellipse(128, 93, 4, 4, LANTERN_CORE)
    s.rect(118, 84, 21, 5, BRONZE)
    s.poly([(112, 114), (128, 128), (144, 114)], RUST_1)
    # lantern glow
    for y in range(70, 170):
        for x in range(70, 186):
            d = math.sqrt((x - 128) ** 2 + (y - 100) ** 2)
            if d < 55:
                a = int(50 * (1 - d / 55) ** 2)
                s.p(x, y, (255, 220, 120, a))

    # five type living-things as small ambient marks along the floor
    # wisp spark
    s.ellipsoid(48, 168, 7, 6, WISP_GOLD, WISP_GOLD2, WISP_CORE)
    s.line(42, 174, 38, 186, WISP_BLUE3, 1)
    s.line(48, 176, 48, 190, WISP_BLUE2, 1)
    s.line(54, 174, 58, 186, WISP_BLUE3, 1)
    # iron cobble lump
    s.ellipsoid(92, 200, 16, 10, IRON_2, IRON_0, IRON_3)
    s.line(80, 198, 104, 198, IRON_0, 1)
    s.line(86, 192, 98, 204, RUST_1, 1)
    s.disc(84, 210, 3, IRON_1)
    s.disc(92, 212, 3, RUST_0)
    s.disc(100, 210, 3, IRON_1)
    # bloom briar
    s.ellipsoid(168, 196, 8, 10, SEED_1, SEED_0, SEED_2)
    s.poly([(168, 176), (164, 190), (172, 190)], BLOOM_2)
    s.poly([(158, 186), (150, 178), (162, 192)], BLOOM_1)
    s.poly([(178, 186), (186, 176), (174, 192)], BLOOM_2)
    s.line(164, 206, 160, 220, SEED_0, 2)
    s.line(172, 206, 176, 220, BLOOM_1, 2)
    # dusk bone-fog
    s.ellipse(210, 160, 11, 10, BONE_0)
    s.ellipse(210, 160, 9, 8, DUSK_2)
    s.disc(205, 158, 3, DUSK_0)
    s.disc(215, 158, 3, DUSK_0)
    s.p(205, 158, DUSK_4)
    s.p(215, 158, DUSK_4)
    s.ellipse(210, 176, 8, 12, C("4A2A68", 120))
    # tide coil
    for t in range(14):
        ang = t * 0.55
        x = 128 + 52 + int(math.cos(ang) * (6 + t * 0.4))
        y = 222 + int(math.sin(ang) * (4 + t * 0.25))
        s.disc(x, y, 3 if t < 10 else 2, TIDE_3 if t % 2 == 0 else TIDE_2)
    s.disc(186, 218, 4, TIDE_4)

    # type color chips (no letters)
    chips = [
        (20, 236, WISP_GOLD, WISP_BLUE2),
        (52, 236, IRON_2, RUST_2),
        (84, 236, BLOOM_2, SEED_2),
        (116, 236, DUSK_3, BONE_1),
        (148, 236, TIDE_3, TIDE_5),
    ]
    for x, y, a, b in chips:
        s.rect(x, y, 18, 10, a)
        s.rect(x + 9, y, 9, 10, b)
        s.rect(x, y, 18, 1, INK)
        s.rect(x, y + 9, 18, 1, INK)
        s.rect(x, y, 1, 10, INK)
        s.rect(x + 17, y, 1, 10, INK)

    s.save(os.path.join(OUT, "style_frame.png"))
    return s.im


# ---------------------------------------------------------------------------
# PLAYER
# ---------------------------------------------------------------------------
def _lantern(s: Spr, lx, ly, scale=1.0):
    r = 4.2 * scale
    s.disc(lx, ly, r + 5, C("FFE566", 36))
    s.ellipse(lx, ly, r + 1.2, r + 2.2, UMBER)
    s.ellipse(lx, ly, r, r + 1.2, LANTERN_DIM)
    s.ellipse(lx, ly - 0.6 * scale, r - 1.4, r - 0.4, LANTERN)
    s.disc(lx, ly - 1.1 * scale, max(1.3, 1.7 * scale), LANTERN_CORE)
    s.p(int(lx), int(ly - 1.6 * scale), C("FFFFFF"))
    s.line(lx - r, ly - r, lx - r, ly + r + 1, BRONZE, 1)
    s.line(lx + r, ly - r, lx + r, ly + r + 1, BRONZE, 1)
    s.line(lx - r, ly - r - 1, lx + r, ly - r - 1, BRONZE_HI, 1)
    s.line(lx - r, ly + r + 1, lx + r, ly + r + 1, BRONZE, 1)


def _ragged_hem(s, y, x0, x1, col):
    x = x0
    toggle = 0
    while x < x1:
        w = 2 + (toggle % 3)
        drop = 1 + (toggle % 2)
        s.rect(x, y, w, drop + 1, col)
        x += w
        toggle += 1


def draw_player(facing: str) -> Spr:
    s = Spr(64, 64)
    s.ground_shadow(32, 59, 13, 4, 85)

    if facing == "down":
        # cloak — A-line, not a rectangle
        s.poly([(24, 24), (40, 24), (48, 52), (16, 52)], CLOAK_1)
        s.poly([(26, 26), (38, 26), (42, 50), (22, 50)], CLOAK_2)
        s.poly([(28, 28), (32, 30), (30, 50), (24, 48)], CLOAK_0)  # left fold
        s.line(36, 28, 40, 48, CLOAK_3, 1)
        _ragged_hem(s, 51, 16, 48, CLOAK_0)
        # rope belt
        s.rect(22, 38, 20, 2, C("6B5428"))
        s.p(32, 40, BRONZE)
        # hood cowl
        s.poly([(20, 22), (32, 10), (44, 22), (40, 26), (24, 26)], CLOAK_2)
        s.ellipse(32, 20, 11, 9, CLOAK_1)
        s.poly([(22, 18), (32, 11), (42, 18), (38, 24), (26, 24)], CLOAK_2)
        # dark recess, weathered face (no cute eyes)
        s.ellipse(32, 22, 6, 7, CLOAK_0)
        s.ellipse(32, 23, 4, 5, SKIN_0)
        s.rect(29, 22, 6, 2, C("1A100C"))  # brow shadow
        s.p(30, 23, LANTERN_DIM)
        s.p(35, 23, LANTERN_DIM)
        s.rect(31, 26, 3, 1, SKIN_0)
        # boots
        s.rect(24, 52, 6, 6, CLOAK_0)
        s.rect(34, 52, 6, 6, CLOAK_0)
        s.rect(23, 56, 8, 4, BOOT_0)
        s.rect(33, 56, 8, 4, BOOT_0)
        s.rect(23, 57, 8, 1, BOOT_1)
        s.rect(33, 57, 8, 1, BOOT_1)
        # lamp-staff, character's right = viewer's left
        s.line(17, 18, 20, 56, STAFF, 2)
        s.line(18, 18, 21, 56, STAFF_HI, 1)
        _lantern(s, 16, 17, 1.05)
        s.disc(20, 40, 2.2, SKIN_1)  # hand on staff
        s.disc(41, 41, 2, SKIN_0)    # other hand in cloak

    elif facing == "up":
        # back of cloak — no face, bedroll to distinguish from down
        s.poly([(24, 24), (40, 24), (48, 52), (16, 52)], CLOAK_1)
        s.poly([(26, 26), (38, 26), (40, 50), (24, 50)], CLOAK_0)
        s.line(32, 26, 32, 50, CLOAK_2, 1)  # spine seam
        s.line(28, 30, 28, 48, CLOAK_1, 1)
        s.line(36, 30, 36, 48, CLOAK_1, 1)
        _ragged_hem(s, 51, 16, 48, CLOAK_0)
        s.rect(22, 38, 20, 2, C("4A3820"))
        # bedroll across the shoulders
        s.ellipse(32, 30, 12, 5, C("3A2818"))
        s.ellipse(32, 29, 11, 4, C("5A4030"))
        s.line(21, 30, 43, 30, C("2A1C10"), 1)
        s.rect(30, 27, 4, 6, C("6B5428"))  # strap
        # hood back — round cowl, peak
        s.ellipse(32, 20, 11, 10, CLOAK_2)
        s.ellipse(32, 18, 9, 8, CLOAK_3)
        s.poly([(21, 20), (32, 9), (43, 20), (38, 24), (26, 24)], CLOAK_2)
        s.p(32, 12, CLOAK_3)
        # no face opening
        s.rect(24, 52, 6, 6, CLOAK_0)
        s.rect(34, 52, 6, 6, CLOAK_0)
        s.rect(23, 56, 8, 4, BOOT_0)
        s.rect(33, 56, 8, 4, BOOT_0)
        # staff on character's right = viewer's right (back view)
        s.line(47, 18, 44, 56, STAFF, 2)
        s.line(48, 18, 45, 56, STAFF_HI, 1)
        _lantern(s, 48, 17, 1.05)

    elif facing == "left":
        # trailing cloak to the right
        s.poly([(30, 24), (38, 22), (46, 34), (42, 52), (24, 52), (20, 36)], CLOAK_1)
        s.poly([(28, 26), (36, 26), (38, 50), (26, 50)], CLOAK_2)
        _ragged_hem(s, 51, 24, 44, CLOAK_0)
        # hood profile, trailing
        s.poly([(18, 16), (32, 10), (38, 20), (30, 26), (20, 24)], CLOAK_2)
        s.ellipse(26, 20, 8, 9, CLOAK_1)
        # face profile in cowl
        s.poly([(16, 20), (26, 18), (26, 28), (18, 28), (14, 24)], SKIN_1)
        s.p(17, 22, C("1A100C"))  # eye slit
        s.p(16, 22, LANTERN_DIM)
        s.p(15, 24, SKIN_2)  # nose
        s.rect(16, 26, 3, 1, SKIN_0)
        s.rect(28, 52, 6, 6, CLOAK_0)
        s.rect(26, 56, 8, 4, BOOT_0)
        s.rect(26, 57, 8, 1, BOOT_1)
        # lantern leading left
        s.line(12, 20, 20, 54, STAFF, 2)
        s.line(13, 20, 21, 54, STAFF_HI, 1)
        _lantern(s, 11, 18, 1.05)
        s.disc(18, 38, 2.2, SKIN_1)

    elif facing == "right":
        s.poly([(34, 24), (26, 22), (18, 34), (22, 52), (40, 52), (44, 36)], CLOAK_1)
        s.poly([(36, 26), (28, 26), (26, 50), (38, 50)], CLOAK_2)
        _ragged_hem(s, 51, 20, 42, CLOAK_0)
        s.poly([(46, 16), (32, 10), (26, 20), (34, 26), (44, 24)], CLOAK_2)
        s.ellipse(38, 20, 8, 9, CLOAK_1)
        s.poly([(48, 20), (38, 18), (38, 28), (46, 28), (50, 24)], SKIN_1)
        s.p(46, 22, C("1A100C"))
        s.p(47, 22, LANTERN_DIM)
        s.p(48, 24, SKIN_2)
        s.rect(45, 26, 3, 1, SKIN_0)
        s.rect(30, 52, 6, 6, CLOAK_0)
        s.rect(30, 56, 8, 4, BOOT_0)
        s.rect(30, 57, 8, 1, BOOT_1)
        s.line(52, 20, 44, 54, STAFF, 2)
        s.line(51, 20, 43, 54, STAFF_HI, 1)
        _lantern(s, 53, 18, 1.05)
        s.disc(46, 38, 2.2, SKIN_1)

    s.outline(PLAYER_OUT, expand=True)
    return s


def draw_glimmerling() -> Spr:
    s = Spr(64, 64)
    s.ground_shadow(32, 54, 11, 3, 45)
    s.ellipse(32, 28, 18, 14, C("F5E6A3", 38))
    s.ellipse(32, 28, 12, 10, C("C8E8F8", 48))

    legs = [
        ((24, 30), (10, 22), (7, 18)),
        ((22, 34), (7, 36), (4, 40)),
        ((24, 38), (11, 50), (8, 54)),
        ((40, 30), (54, 22), (57, 18)),
        ((42, 34), (57, 36), (60, 40)),
        ((40, 38), (53, 50), (56, 54)),
    ]
    for a, b, cpt in legs:
        s.line(a[0], a[1], b[0], b[1], WISP_BLUE3, 2)
        s.line(b[0], b[1], cpt[0], cpt[1], WISP_BLUE2, 1)
        s.p(cpt[0], cpt[1], WISP_GOLD)

    # elongated thorax, not a round mascot
    s.ellipsoid(32, 33, 8, 6, WISP_GOLD2, WISP_BLUE3, WISP_GOLD, light=(-0.3, -0.8), steps=5)
    s.ellipsoid(32, 26, 8, 7, WISP_GOLD, WISP_GOLD2, WISP_CORE, light=(-0.35, -0.85), steps=5)
    s.ellipse(32, 26, 4, 3, WISP_CORE)
    s.p(31, 24, C("FFFFFF"))
    s.p(32, 24, C("FFFFFF"))

    # wedge head + mandibles
    s.poly([(28, 20), (32, 12), (36, 20), (34, 24), (30, 24)], WISP_BLUE2)
    s.poly([(29, 18), (32, 13), (35, 18), (33, 22), (31, 22)], WISP_CORE)
    s.line(28, 20, 23, 17, WISP_BLUE3, 1)
    s.line(36, 20, 41, 17, WISP_BLUE3, 1)
    s.p(23, 17, WISP_GOLD)
    s.p(41, 17, WISP_GOLD)
    s.p(30, 18, WISP_BLUE3)
    s.p(34, 18, WISP_BLUE3)
    s.line(30, 14, 25, 6, WISP_BLUE2, 1)
    s.line(34, 14, 39, 6, WISP_BLUE2, 1)
    s.disc(25, 6, 1.5, WISP_GOLD)
    s.disc(39, 6, 1.5, WISP_GOLD)

    s.outline(WISP_OUT, expand=True)
    s.glow(C("FFE566", 70), radius=4, thresh=160)
    return s


def draw_cobbleback() -> Spr:
    s = Spr(64, 64)
    s.ground_shadow(32, 57, 22, 4, 95)

    # six squat legs — wide stance, rust joints
    for i, lx in enumerate((9, 18, 26, 38, 46, 55)):
        rust = RUST_1 if i % 2 else IRON_1
        s.rect(lx - 3, 44, 7, 10, rust)
        s.rect(lx - 4, 52, 9, 4, IRON_0)
        s.rect(lx - 3, 47, 7, 1, RUST_2)

    # low wide shell
    s.ellipsoid(32, 34, 27, 16, IRON_2, IRON_0, IRON_3, light=(-0.4, -0.9), steps=4)
    plates = [
        (18, 26, 8, 6), (32, 24, 11, 7), (46, 26, 8, 6),
        (14, 35, 9, 7), (32, 34, 13, 8), (50, 35, 9, 7),
        (20, 43, 10, 6), (44, 43, 10, 6),
    ]
    for i, (cx, cy, rx, ry) in enumerate(plates):
        mid = IRON_3 if i % 2 == 0 else IRON_2
        sh = IRON_1 if i % 2 == 0 else IRON_0
        hi = IRON_4 if i % 3 == 0 else IRON_3
        s.ellipsoid(cx, cy, rx, ry, mid, sh, hi, light=(-0.5, -0.8), steps=3)
        s.line(cx - rx + 2, cy, cx + rx - 2, cy + 1, IRON_0, 1)
        if i % 2:
            s.line(cx - 2, cy - 2, cx + 4, cy + 3, RUST_1, 1)

    s.disc(22, 32, 2.2, RUST_2)
    s.disc(42, 40, 2.4, RUST_1)
    s.disc(16, 40, 1.8, RUST_3)
    s.line(26, 28, 38, 36, RUST_0, 1)

    # beetle head protruding from under the front of the shell
    s.ellipsoid(32, 48, 9, 6, IRON_1, IRON_0, IRON_2, steps=3)
    s.poly([(25, 50), (22, 56), (28, 52)], RUST_2)
    s.poly([(39, 50), (42, 56), (36, 52)], RUST_2)
    # ember slits — predatory, not cute
    s.rect(27, 47, 4, 2, C("2A1008"))
    s.rect(34, 47, 4, 2, C("2A1008"))
    s.p(28, 47, C("E07040"))
    s.p(29, 47, RUST_3)
    s.p(35, 47, C("E07040"))
    s.p(36, 47, RUST_3)

    s.outline(IRON_OUT, expand=True)
    return s


def draw_briarseed() -> Spr:
    s = Spr(64, 64)
    s.ground_shadow(32, 58, 13, 4, 72)

    # knobby root-legs, uneven
    s.line(25, 44, 14, 58, SEED_0, 3)
    s.line(25, 44, 16, 56, BLOOM_1, 2)
    s.disc(14, 58, 2.2, SEED_1)
    s.p(18, 52, BLOOM_2)
    s.line(32, 46, 33, 58, SEED_0, 3)
    s.line(32, 46, 32, 57, BLOOM_0, 2)
    s.disc(33, 58, 2.2, SEED_0)
    s.line(39, 44, 52, 56, SEED_1, 3)
    s.line(39, 44, 50, 54, BLOOM_1, 2)
    s.disc(52, 56, 2.2, SEED_2)
    s.line(30, 48, 20, 54, BLOOM_0, 2)
    s.disc(20, 54, 1.6, BLOOM_2)

    # teardrop seed
    s.ellipsoid(32, 30, 14, 18, SEED_1, SEED_0, SEED_2, light=(-0.4, -0.7), steps=4)
    # living split — viscera, not a face
    s.poly([(31, 12), (35, 14), (36, 38), (32, 46), (28, 38)], BLOOM_1)
    s.line(32, 14, 32, 44, BLOOM_0, 1)
    s.ellipse(32, 30, 3, 7, BLOOM_2)
    s.p(32, 28, BLOOM_4)
    s.p(32, 32, C("1A2A18"))

    thorns = [
        [(32, 4), (27, 16), (37, 16)],
        [(16, 18), (4, 10), (22, 26)],
        [(48, 18), (60, 8), (42, 26)],
        [(12, 34), (2, 36), (16, 42)],
        [(52, 32), (62, 28), (48, 40)],
        [(20, 10), (12, 2), (26, 14)],
        [(44, 8), (52, 0), (40, 16)],
        [(18, 44), (8, 52), (24, 46)],
        [(46, 44), (56, 50), (42, 42)],
    ]
    cols = [BLOOM_2, BLOOM_1, BLOOM_3, BLOOM_0, BLOOM_2, BLOOM_1, BLOOM_0, BLOOM_1, BLOOM_2]
    for th, col in zip(thorns, cols):
        s.poly(th, col)
        s.line(th[0][0], th[0][1], th[1][0], th[1][1], BLOOM_3, 1)

    # barbs, not eyes
    s.line(24, 20, 18, 14, BLOOM_0, 1)
    s.p(18, 14, BLOOM_3)
    s.line(40, 22, 48, 14, BLOOM_0, 1)
    s.p(48, 14, BLOOM_3)

    s.outline(BLOOM_OUT, expand=True)
    return s


def draw_marrowl() -> Spr:
    s = Spr(64, 64)
    s.ground_shadow(32, 56, 10, 3, 35)

    # dissolving fog body — drips, not stick-legs
    s.ellipse(32, 40, 11, 12, C("2D1A40", 200))
    s.ellipse(32, 46, 10, 10, C("4A2A68", 140))
    s.ellipse(26, 50, 7, 8, C("4A2A68", 90))
    s.ellipse(38, 50, 7, 9, C("6A5080", 85))
    s.ellipse(32, 54, 5, 6, C("8A70A0", 60))
    s.ellipse(20, 48, 4, 6, C("4A2A68", 70))
    s.ellipse(44, 48, 4, 7, C("6A5080", 65))

    # tattered bone-wings
    s.poly([(18, 28), (2, 18), (1, 30), (8, 38), (20, 36)], DUSK_2)
    s.poly([(16, 30), (4, 24), (5, 34), (18, 34)], BONE_0)
    s.line(4, 20, 3, 36, BONE_1, 1)
    s.line(10, 22, 8, 38, BONE_0, 1)
    s.poly([(46, 28), (62, 18), (63, 30), (56, 38), (44, 36)], DUSK_2)
    s.poly([(48, 30), (60, 24), (59, 34), (46, 34)], BONE_0)
    s.line(60, 20, 61, 36, BONE_1, 1)
    s.line(54, 22, 56, 38, BONE_0, 1)

    # rib cage
    s.ellipsoid(32, 34, 10, 10, DUSK_2, DUSK_0, DUSK_3, steps=4)
    s.line(25, 32, 25, 42, BONE_0, 1)
    s.line(32, 30, 32, 44, BONE_1, 1)
    s.line(39, 32, 39, 42, BONE_0, 1)
    s.line(26, 36, 38, 36, BONE_0, 1)

    # elongated skull
    s.ellipsoid(32, 18, 13, 11, BONE_1, DUSK_2, BONE_2, light=(-0.3, -0.8), steps=4)
    # bone horns — thick shards, not antennae
    s.poly([(20, 12), (12, 0), (18, 2), (26, 16)], BONE_1)
    s.poly([(44, 12), (52, 0), (46, 2), (38, 16)], BONE_1)
    s.poly([(18, 8), (12, 0), (22, 12)], BONE_2)
    s.poly([(46, 8), (52, 0), (42, 12)], BONE_2)

    # hollow sockets — EMPTY, faint violet only (no pupils)
    s.ellipse(25, 19, 5, 5, DUSK_0)
    s.ellipse(39, 19, 5, 5, DUSK_0)
    s.ellipse(25, 19, 3, 3, C("050308"))
    s.ellipse(39, 19, 3, 3, C("050308"))
    s.p(26, 20, DUSK_3)  # distant cave-gleam, not a pupil
    s.p(40, 20, DUSK_3)

    # bone-shard beak
    s.poly([(30, 24), (32, 33), (34, 24)], BONE_0)
    s.p(32, 28, DUSK_1)
    s.line(20, 14, 24, 20, DUSK_2, 1)
    s.line(44, 14, 40, 20, DUSK_2, 1)

    s.outline(DUSK_OUT, expand=True)
    s.glow(C("6A5080", 75), radius=3, thresh=90)
    return s


def draw_brinekit() -> Spr:
    s = Spr(64, 64)
    s.ground_shadow(34, 50, 16, 4, 60)

    pts = []
    for t in range(0, 28):
        u = t / 27.0
        x = 12 + u * 46
        y = 30 + math.sin(u * math.pi * 2.2) * 8 * (0.4 + u * 0.6)
        r = 7.5 * (1 - u * 0.75)
        pts.append((x, y, r))
        mid = TIDE_3 if t % 2 == 0 else TIDE_2
        s.ellipsoid(x, y, r, r * 0.72, mid, TIDE_0, TIDE_4, light=(-0.5, -0.9), steps=4)

    for t in range(4, 20):
        x, y, r = pts[t]
        s.p(int(x), int(y - r * 0.4), TIDE_5)
        s.p(int(x + 1), int(y - r * 0.35), TIDE_4)

    for t in (6, 10, 14, 18):
        x, y, r = pts[t]
        s.poly([(x - 2, y - r + 1), (x, y - r - 6), (x + 2, y - r + 1)], TIDE_1)
        s.line(x, y - r, x, y - r - 6, TIDE_4, 1)

    hx, hy = 14, 28
    s.ellipsoid(hx, hy, 9, 7, TIDE_3, TIDE_0, TIDE_4, light=(-0.6, -0.5), steps=4)
    s.poly([(16, 26), (4, 30), (16, 34), (18, 30)], TIDE_2)
    s.poly([(14, 28), (5, 30), (14, 32)], TIDE_1)
    s.p(8, 29, TIDE_TEETH)
    s.p(10, 29, TIDE_TEETH)
    s.p(12, 29, TIDE_TEETH)
    s.p(9, 31, TIDE_TEETH)
    s.p(11, 31, TIDE_TEETH)
    s.rect(16, 26, 3, 1, C("0A1010"))
    s.p(17, 26, C("7AD4C8"))
    s.poly([(16, 22), (13, 13), (20, 22)], TIDE_1)
    s.line(13, 13, 18, 22, TIDE_4, 1)
    s.poly([(20, 22), (25, 15), (22, 24)], TIDE_2)
    s.line(20, 28, 22, 32, TIDE_0, 1)
    s.line(22, 27, 24, 31, TIDE_0, 1)
    tx, ty, _ = pts[-1]
    s.poly([(tx, ty), (tx + 8, ty - 6), (tx + 2, ty)], TIDE_2)
    s.poly([(tx, ty), (tx + 8, ty + 5), (tx + 2, ty + 1)], TIDE_1)

    s.outline(TIDE_OUT, expand=True)
    return s


def make_floor_tile() -> Image.Image:
    s = Spr(32, 32)
    for y in range(32):
        for x in range(32):
            row = y // 16
            lx = (x + (8 if row % 2 else 0)) % 16
            ly = y % 16
            n = hash01(x, y, 7)
            n2 = hash01(x // 2, y // 2, 19)
            grout = lx < 2 or ly < 2
            if grout:
                s.pset(x, y, lerp4(C("1A140E"), C("3A2814"), 0.35 + n * 0.25))
            else:
                base = lerp4(C("3A3630"), C("6E675A"), 0.25 + n2 * 0.55)
                wash = max(0, 1 - math.sqrt((lx - 5) ** 2 + (ly - 5) ** 2) / 13)
                col = lerp4(base, (110, 88, 52, 255), wash * 0.42)
                if n > 0.92:
                    col = lerp4(col, STONE_0, 0.45)
                elif n < 0.08:
                    col = lerp4(col, LANTERN_DIM, 0.22)
                s.pset(x, y, col)
    return s.im


def make_wall_tile() -> Image.Image:
    s = Spr(32, 32)
    for y in range(32):
        course = y // 8
        for x in range(32):
            ox = (x + (course % 2) * 10) % 16
            ly = y % 8
            n = hash01(x, y, 31 + course)
            grout = ox < 2 or ly == 0 or ly == 7
            if grout:
                s.pset(x, y, C("14100C"))
            else:
                base = lerp4(C("2A2622"), C("5C564C"), 0.25 + n * 0.55)
                if ly <= 2:
                    base = lerp4(base, C("7A7264"), 0.4)
                if ly >= 6:
                    base = lerp4(base, C("1A1612"), 0.45)
                if n > 0.95:
                    base = lerp4(base, BLOOM_0, 0.4)
                if n < 0.06:
                    base = lerp4(base, BRONZE, 0.12)
                s.pset(x, y, base)
    for x in range(32):
        s.p(x, 0, C("0E0C0A"))
        s.p(x, 1, lerp4(STONE_2, BRONZE, 0.2))
    return s.im


def make_stairs_tile() -> Image.Image:
    s = Spr(32, 32)
    for y in range(32):
        for x in range(32):
            n = hash01(x, y, 44)
            s.pset(x, y, lerp4(C("12100E"), STONE_2, n * 0.45))
    steps = [
        (0, 26, 32, 6, STONE_4),
        (3, 21, 26, 5, STONE_3),
        (6, 16, 20, 5, STONE_2),
        (9, 12, 14, 4, STONE_1),
        (11, 8, 10, 4, STONE_0),
    ]
    for x, y, w, h, col in steps:
        s.rect(x, y, w, h, col)
        s.rect(x, y, w, 1, lerp4(col, LANTERN_DIM, 0.3))
        s.rect(x, y + h - 1, w, 1, IRON_0)
        s.line(x, y, 16, 4, STONE_0, 1)
        s.line(x + w - 1, y, 16, 4, STONE_0, 1)
    s.ellipse(16, 6, 5, 4, DUSK_2)
    s.ellipse(16, 6, 3, 2, DUSK_3)
    s.p(16, 6, LANTERN)
    s.p(15, 6, WISP_GOLD)
    s.p(17, 6, DUSK_5)
    s.rect(0, 0, 32, 3, STONE_1)
    s.rect(0, 29, 32, 3, STONE_2)
    return s.im


def chrome_panel(s: Spr, x, y, w, h, fill=INK):
    s.rect(x, y, w, h, fill)
    s.rect(x, y, w, 1, BRONZE_HI)
    s.rect(x, y + h - 1, w, 1, C("2A1C0C"))
    s.rect(x, y, 1, h, BRONZE)
    s.rect(x + w - 1, y, 1, h, C("2A1C0C"))
    s.rect(x + 1, y + 1, w - 2, 1, C("3A3020"))
    s.rect(x + 1, y + h - 2, w - 2, 1, C("1A1008"))


def make_wordmark() -> Image.Image:
    w, h = 192, 48
    s = Spr(w, h)
    chrome_panel(s, 0, 0, w, h, C("140E0A"))
    s.rect(3, 3, w - 6, h - 6, C("1C1410"))
    s.disc(16, 24, 4, LANTERN_DIM)
    s.disc(16, 23, 2, LANTERN)
    s.p(16, 22, LANTERN_CORE)
    s.line(16, 12, 16, 18, BRONZE, 1)
    s.disc(176, 24, 4, LANTERN_DIM)
    s.disc(176, 23, 2, LANTERN)
    s.p(176, 22, LANTERN_CORE)
    s.line(176, 12, 176, 18, BRONZE, 1)
    tw = text_width("Wyrdling", F7, scale=2, tracking=1)
    tx = (w - tw) // 2
    ty = 12
    blit_font(s, "Wyrdling", tx, ty, F7, PARCHMENT, scale=2, shadow=C("000000", 200), tracking=1)
    s.rect(tx, ty + 24, tw, 1, BRONZE)
    s.rect(tx, ty + 25, tw, 1, C("2A1C0C"))
    return s.im


def make_hp_bar() -> Image.Image:
    w, h = 128, 32
    s = Spr(w, h)

    def draw_track(yoff, filled=False):
        chrome_panel(s, 0, yoff, 128, 16, C("140E0A"))
        s.rect(4, yoff + 4, 120, 8, C("1A1010"))
        s.rect(4, yoff + 4, 120, 1, C("080404"))
        if filled:
            for x in range(4, 124):
                t = (x - 4) / 120
                col = lerp4(C("6B1A18"), C("C45A3A"), 0.3 + 0.4 * math.sin(t * math.pi))
                for y in range(yoff + 4, yoff + 12):
                    yy = y - (yoff + 4)
                    if yy == 0:
                        c = lerp4(col, C("E8A090"), 0.35)
                    elif yy == 7:
                        c = lerp4(col, C("3A0A08"), 0.4)
                    else:
                        c = col
                    s.pset(x, y, c)
            s.rect(4, yoff + 4, 120, 1, C("E07060"))
        s.rect(2, yoff + 5, 3, 6, BRONZE)
        s.p(3, yoff + 7, LANTERN)

    draw_track(0, filled=False)
    draw_track(16, filled=True)
    return s.im


def make_button(label: str) -> Image.Image:
    w, h = 80, 28
    s = Spr(w, h)
    chrome_panel(s, 0, 0, w, h, C("1A1410"))
    s.rect(2, 2, w - 4, h - 4, C("241C16"))
    for rx in (4, w - 6):
        for ry in (4, h - 6):
            s.p(rx, ry, BRONZE)
            s.p(rx + 1, ry, BRONZE_HI)
    tw = text_width(label, F5, scale=2, tracking=1)
    tx = (w - tw) // 2
    ty = (h - 7 * 2) // 2
    blit_font(s, label, tx, ty, F5, PARCHMENT, scale=2, shadow=C("000000"), tracking=1)
    return s.im


def make_icon_wisp() -> Image.Image:
    s = Spr(32, 32)
    s.disc(16, 16, 11, C("F5E6A3", 40))
    # six-point spark, no face
    pts = []
    for i in range(6):
        a = i * math.pi / 3 - math.pi / 2
        pts.append((16 + math.cos(a) * 12, 16 + math.sin(a) * 12))
        pts.append((16 + math.cos(a + math.pi / 6) * 5, 16 + math.sin(a + math.pi / 6) * 5))
    s.poly(pts, WISP_GOLD)
    s.disc(16, 16, 5, WISP_BLUE2)
    s.disc(16, 16, 3, WISP_GOLD)
    s.p(16, 15, WISP_CORE)
    s.p(16, 16, C("FFFFFF"))
    s.outline(WISP_OUT, expand=True)
    return crop_center(s.im, 32, pad=2)


def make_icon_iron() -> Image.Image:
    s = Spr(32, 32)
    # riveted ingot — three rivets, not two "eyes"
    s.poly([(6, 12), (16, 6), (26, 12), (24, 24), (8, 24)], IRON_2)
    s.poly([(8, 13), (16, 9), (24, 13), (22, 22), (10, 22)], IRON_3)
    s.line(16, 9, 16, 22, IRON_0, 1)
    s.line(10, 18, 22, 18, RUST_1, 1)
    s.disc(12, 14, 1.6, IRON_4)
    s.disc(20, 14, 1.6, IRON_4)
    s.disc(16, 20, 1.6, RUST_2)
    s.rect(10, 24, 12, 3, RUST_1)
    s.outline(IRON_OUT, expand=True)
    return crop_center(s.im, 32, pad=2)


def make_icon_bloom() -> Image.Image:
    s = Spr(32, 32)
    s.ellipse(16, 19, 7, 8, SEED_1)
    s.ellipse(16, 19, 5, 6, SEED_2)
    s.poly([(16, 3), (13, 16), (19, 16)], BLOOM_2)
    s.poly([(5, 10), (14, 17), (12, 19)], BLOOM_1)
    s.poly([(27, 10), (18, 17), (20, 19)], BLOOM_3)
    s.poly([(8, 26), (14, 21), (11, 28)], BLOOM_0)
    s.poly([(24, 26), (18, 21), (21, 28)], BLOOM_1)
    s.line(16, 8, 16, 24, BLOOM_0, 1)
    s.outline(BLOOM_OUT, expand=True)
    return crop_center(s.im, 32, pad=2)


def make_icon_dusk() -> Image.Image:
    s = Spr(32, 32)
    s.disc(16, 17, 11, DUSK_3)
    s.disc(18, 15, 8, DUSK_1)
    # hollow socket, bone shards on top — not a smiley
    s.disc(12, 17, 4, DUSK_0)
    s.p(11, 16, DUSK_4)
    s.poly([(14, 5), (12, 13), (16, 13)], BONE_1)
    s.poly([(19, 4), (17, 13), (21, 12)], BONE_0)
    s.poly([(23, 8), (20, 14), (24, 14)], BONE_1)
    s.outline(DUSK_OUT, expand=True)
    return crop_center(s.im, 32, pad=2)


def make_icon_tide() -> Image.Image:
    s = Spr(32, 32)
    for t in range(22):
        ang = t * 0.5 + 0.3
        rad = 2.5 + t * 0.48
        x = 16 + math.cos(ang) * rad
        y = 17 + math.sin(ang) * rad * 0.82
        s.disc(x, y, 2.5 if t < 14 else 1.7, TIDE_3 if t % 2 == 0 else TIDE_2)
    s.disc(21, 9, 2.2, TIDE_5)
    s.p(22, 8, TIDE_4)
    s.outline(TIDE_OUT, expand=True)
    return crop_center(s.im, 32, pad=2)


def assert_rgba(path, w, h):
    im = Image.open(path)
    assert im.mode == "RGBA", (path, im.mode)
    assert im.size == (w, h), (path, im.size)
    # no magenta pixels
    pix = im.getdata()
    mag = sum(1 for p in pix if p[0] >= 250 and p[1] <= 5 and p[2] >= 250 and p[3] > 0)
    assert mag == 0, (path, "magenta leftover", mag)
    return im


def main():
    print("style frame...")
    make_style_frame()

    print("player...")
    for facing in ("down", "up", "left", "right"):
        spr = draw_player(facing)
        save_sprite(spr, f"player_idle_{facing}.png", 64, pad=2)

    print("creatures...")
    save_sprite(draw_glimmerling(), "glimmerling.png", 64, pad=3)
    save_sprite(draw_cobbleback(), "cobbleback.png", 64, pad=2)
    save_sprite(draw_briarseed(), "briarseed.png", 64, pad=2)
    save_sprite(draw_marrowl(), "marrowl.png", 64, pad=3)
    save_sprite(draw_brinekit(), "brinekit.png", 64, pad=2)

    print("tiles...")
    make_floor_tile().save(os.path.join(OUT, "tile_floor.png"), "PNG")
    make_wall_tile().save(os.path.join(OUT, "tile_wall.png"), "PNG")
    make_stairs_tile().save(os.path.join(OUT, "tile_stairs.png"), "PNG")

    print("ui...")
    make_wordmark().save(os.path.join(OUT, "ui_wordmark.png"), "PNG")
    make_hp_bar().save(os.path.join(OUT, "ui_hp_bar.png"), "PNG")
    make_button("Strike").save(os.path.join(OUT, "ui_btn_strike.png"), "PNG")
    make_button("Bind").save(os.path.join(OUT, "ui_btn_bind.png"), "PNG")
    make_button("Swap").save(os.path.join(OUT, "ui_btn_swap.png"), "PNG")
    make_button("Flee").save(os.path.join(OUT, "ui_btn_flee.png"), "PNG")

    print("icons...")
    make_icon_wisp().save(os.path.join(OUT, "icon_wisp.png"), "PNG")
    make_icon_iron().save(os.path.join(OUT, "icon_iron.png"), "PNG")
    make_icon_bloom().save(os.path.join(OUT, "icon_bloom.png"), "PNG")
    make_icon_dusk().save(os.path.join(OUT, "icon_dusk.png"), "PNG")
    make_icon_tide().save(os.path.join(OUT, "icon_tide.png"), "PNG")

    # verify sizes
    sizes = {
        "style_frame.png": (256, 256),
        "player_idle_down.png": (64, 64),
        "player_idle_up.png": (64, 64),
        "player_idle_left.png": (64, 64),
        "player_idle_right.png": (64, 64),
        "glimmerling.png": (64, 64),
        "cobbleback.png": (64, 64),
        "briarseed.png": (64, 64),
        "marrowl.png": (64, 64),
        "brinekit.png": (64, 64),
        "tile_floor.png": (32, 32),
        "tile_wall.png": (32, 32),
        "tile_stairs.png": (32, 32),
        "ui_wordmark.png": (192, 48),
        "ui_hp_bar.png": (128, 32),
        "ui_btn_strike.png": (80, 28),
        "ui_btn_bind.png": (80, 28),
        "ui_btn_swap.png": (80, 28),
        "ui_btn_flee.png": (80, 28),
        "icon_wisp.png": (32, 32),
        "icon_iron.png": (32, 32),
        "icon_bloom.png": (32, 32),
        "icon_dusk.png": (32, 32),
        "icon_tide.png": (32, 32),
    }
    for name, wh in sizes.items():
        p = os.path.join(OUT, name)
        assert_rgba(p, *wh)
        print(" ok", name, wh)


if __name__ == "__main__":
    main()
