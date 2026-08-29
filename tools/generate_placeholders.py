#!/usr/bin/env python3
"""Geometric placeholder art for Wyrdling v0. Arthur will replace these files in-place."""
from __future__ import annotations

import math
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "art"

WISP = (244, 228, 166, 255)
IRON = (107, 114, 128, 255)
BLOOM = (63, 107, 58, 255)
DUSK = (45, 27, 78, 255)
TIDE = (15, 76, 92, 255)
BRASS = (176, 141, 87, 255)
BRASS_DK = (120, 90, 48, 255)
GOLD = (196, 163, 90, 255)
INK = (11, 10, 16, 255)
PAPER = (232, 220, 196, 255)

TYPE_COLORS = {
    "wisp": WISP,
    "iron": IRON,
    "bloom": BLOOM,
    "dusk": DUSK,
    "tide": TIDE,
}

FONT_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT_R = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def rgba(size, color=(0, 0, 0, 0)) -> Image.Image:
    return Image.new("RGBA", size, color)


def save(img: Image.Image, rel: str) -> None:
    path = ART / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "PNG")
    print("wrote", path.relative_to(ROOT), img.size)


def circle(draw, cx, cy, r, fill, outline=None, width=1):
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill, outline=outline, width=width)


def glow_layer(size, cx, cy, r, color, steps=8):
    layer = rgba(size)
    d = ImageDraw.Draw(layer)
    cr, cg, cb = color[:3]
    for i in range(steps, 0, -1):
        a = int(18 + 28 * (i / steps))
        rr = int(r * i / steps)
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=(cr, cg, cb, a))
    return layer.filter(ImageFilter.GaussianBlur(2))


# --- tiles 32x32 ---
def tile_floor(alt=False) -> Image.Image:
    img = rgba((32, 32))
    d = ImageDraw.Draw(img)
    base = (38, 34, 48, 255) if not alt else (34, 40, 44, 255)
    d.rectangle([0, 0, 31, 31], fill=base)
    grout = (24, 22, 30, 255)
    d.line([(0, 31), (31, 31)], fill=grout)
    d.line([(31, 0), (31, 31)], fill=grout)
    speck = (52, 48, 62, 255) if not alt else (46, 58, 54, 255)
    for x, y in ((3, 5), (11, 9), (20, 4), (7, 18), (24, 21), (15, 26), (28, 12)):
        d.point((x, y), fill=speck)
    # faint inner bevel
    hi = (58, 54, 70, 80)
    d.line([(1, 1), (30, 1)], fill=hi)
    d.line([(1, 1), (1, 30)], fill=hi)
    return img


def tile_wall() -> Image.Image:
    img = rgba((32, 32))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 31, 31], fill=(18, 16, 24, 255))
    d.rectangle([2, 2, 29, 29], fill=(28, 24, 36, 255))
    d.rectangle([4, 4, 27, 22], fill=(42, 36, 52, 255))
    d.line([(4, 22), (27, 22), (27, 4)], fill=(16, 14, 20, 255))
    d.line([(4, 4), (27, 4), (4, 4), (4, 22)], fill=(70, 62, 82, 255))
    d.rectangle([8, 8, 14, 14], fill=(34, 30, 44, 255))
    d.rectangle([18, 10, 24, 16], fill=(36, 32, 46, 255))
    return img


def tile_stairs() -> Image.Image:
    img = tile_floor(False)
    d = ImageDraw.Draw(img)
    for i, y in enumerate((6, 11, 16, 21, 26)):
        inset = 4 + i * 2
        d.rectangle([inset, y, 31 - inset, y + 4], fill=(90, 78, 48, 255), outline=(196, 163, 90, 220))
    d.polygon([(15, 3), (17, 3), (16, 1)], fill=GOLD)
    return img


# --- type icons 32x32 ---
def icon_pentagon(color, letter: str) -> Image.Image:
    img = rgba((32, 32))
    cx, cy, r = 16, 17, 12
    pts = []
    for i in range(5):
        a = math.radians(-90 + i * 72)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    base = rgba((32, 32))
    ImageDraw.Draw(base).polygon(pts, fill=color)
    glow = base.filter(ImageFilter.GaussianBlur(1.5))
    img = Image.alpha_composite(glow, img)
    d = ImageDraw.Draw(img)
    d.polygon(pts, fill=color, outline=(255, 255, 255, 180))
    try:
        font = ImageFont.truetype(FONT_B, 11)
    except Exception:
        font = ImageFont.load_default()
    # letter contrast
    ink = (12, 10, 16, 255) if sum(color[:3]) > 280 else (240, 232, 210, 255)
    bbox = d.textbbox((0, 0), letter, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    d.text(((32 - tw) / 2, (32 - th) / 2 - 2), letter, font=font, fill=ink)
    return img


# --- ui ---
def wordmark() -> Image.Image:
    img = rgba((640, 160))
    d = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype(FONT_B, 72)
        small = ImageFont.truetype(FONT_R, 16)
    except Exception:
        font = ImageFont.load_default()
        small = font
    text = "WYRDLING"
    bbox = d.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (640 - tw) / 2
    y = 28
    # glow
    for ox, oy in ((0, 2), (2, 0), (-2, 0), (0, -2), (0, 0)):
        d.text((x + ox, y + oy), text, font=font, fill=(90, 70, 30, 80))
    d.text((x, y), text, font=font, fill=GOLD)
    # underline pentagon ticks
    order = [WISP, IRON, BLOOM, DUSK, TIDE]
    gap = 28
    start = 640 / 2 - 2 * gap
    for i, c in enumerate(order):
        px = start + i * gap
        circle(d, px, 128, 6, c, outline=GOLD, width=1)
    sub = "UNDERCROFT  ·  BIND  ·  DESCEND"
    sb = d.textbbox((0, 0), sub, font=small)
    d.text(((640 - (sb[2] - sb[0])) / 2, 138), sub, font=small, fill=(180, 160, 120, 200))
    return img


def hp_frame() -> Image.Image:
    img = rgba((256, 28))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, 255, 27], radius=4, outline=GOLD, width=2, fill=(16, 14, 22, 220))
    return img


def hp_fill() -> Image.Image:
    img = rgba((248, 20))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, 247, 19], radius=2, fill=(186, 72, 72, 255))
    d.rectangle([0, 0, 247, 6], fill=(220, 120, 110, 90))
    return img


def btn_panel() -> Image.Image:
    img = rgba((192, 56))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, 191, 55], radius=8, fill=(32, 26, 42, 240), outline=GOLD, width=2)
    d.line([(10, 8), (181, 8)], fill=(255, 255, 255, 30))
    return img


def icon_png() -> Image.Image:
    """Project icon: lantern over a pentagon."""
    img = rgba((128, 128), (11, 10, 16, 255))
    d = ImageDraw.Draw(img)
    # dusk field
    d.ellipse([8, 8, 119, 119], fill=DUSK)
    pts = []
    cx, cy, r = 64, 68, 48
    for i in range(5):
        a = math.radians(-90 + i * 72)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    d.polygon(pts, fill=(36, 22, 64, 255), outline=GOLD)
    # lantern
    d.rounded_rectangle([54, 28, 74, 36], radius=2, fill=BRASS_DK)
    d.rounded_rectangle([50, 36, 78, 70], radius=4, fill=BRASS)
    d.rounded_rectangle([54, 40, 74, 64], radius=3, fill=WISP)
    d.rectangle([60, 22, 68, 28], fill=BRASS_DK)
    d.ellipse([56, 44, 72, 60], fill=(255, 244, 200, 180))
    return img


# --- player 64x64 brass-lantern humanoid blob ---
def player_dir(facing: str) -> Image.Image:
    img = rgba((64, 64))
    body = (176, 141, 87, 255)
    shade = (120, 90, 48, 255)
    glow_c = (244, 228, 166, 255)
    cx, cy = 32, 36
    # lantern offset by facing
    lx, ly = 32, 22
    if facing == "down":
        lx, ly = 32, 46
    elif facing == "up":
        lx, ly = 32, 14
    elif facing == "left":
        lx, ly = 16, 30
    elif facing == "right":
        lx, ly = 48, 30

    glow = glow_layer((64, 64), lx, ly, 16, glow_c, steps=6)
    img = Image.alpha_composite(img, glow)
    d = ImageDraw.Draw(img)

    # feet
    d.ellipse([cx - 10, 48, cx - 2, 56], fill=shade)
    d.ellipse([cx + 2, 48, cx + 10, 56], fill=shade)
    # body blob
    d.ellipse([cx - 14, cy - 16, cx + 14, cy + 14], fill=body)
    d.ellipse([cx - 10, cy - 8, cx + 10, cy + 10], fill=(196, 163, 90, 80))
    # head
    d.ellipse([cx - 10, cy - 26, cx + 10, cy - 8], fill=body)
    # eyes shift
    ex = 0
    ey = -18
    if facing == "left":
        ex = -3
    elif facing == "right":
        ex = 3
    elif facing == "down":
        ey = -16
    elif facing == "up":
        ey = -20
    eye = (24, 18, 14, 255)
    if facing != "up":
        d.ellipse([cx - 5 + ex, cy + ey, cx - 1 + ex, cy + ey + 4], fill=eye)
        d.ellipse([cx + 1 + ex, cy + ey, cx + 5 + ex, cy + ey + 4], fill=eye)
    else:
        d.ellipse([cx - 5, cy - 22, cx - 2, cy - 20], fill=eye)
        d.ellipse([cx + 2, cy - 22, cx + 5, cy - 20], fill=eye)

    # lantern (draw after body for down/left/right; before already glowed)
    def draw_lantern(dd, x, y):
        dd.rectangle([x - 4, y - 10, x + 4, y - 7], fill=shade)
        dd.rounded_rectangle([x - 7, y - 7, x + 7, y + 7], radius=2, fill=BRASS)
        dd.rounded_rectangle([x - 5, y - 5, x + 5, y + 5], radius=2, fill=glow_c)
        dd.ellipse([x - 3, y - 3, x + 3, y + 3], fill=(255, 250, 220, 220))

    if facing == "up":
        # lantern behind / above
        tmp = rgba((64, 64))
        draw_lantern(ImageDraw.Draw(tmp), lx, ly)
        img = Image.alpha_composite(tmp, img)
    else:
        draw_lantern(d, lx, ly)
    return img


# --- creatures 64x64 ---
def creature_glimmerling() -> Image.Image:
    img = rgba((64, 64))
    img = Image.alpha_composite(img, glow_layer((64, 64), 32, 30, 22, WISP, 7))
    d = ImageDraw.Draw(img)
    # moth wings
    d.polygon([(32, 28), (8, 12), (10, 36), (28, 34)], fill=(244, 228, 166, 200), outline=GOLD)
    d.polygon([(32, 28), (56, 12), (54, 36), (36, 34)], fill=(244, 228, 166, 200), outline=GOLD)
    d.ellipse([24, 22, 40, 44], fill=GOLD)
    d.ellipse([28, 26, 36, 34], fill=(255, 250, 220, 255))
    # antennae
    d.line([(30, 24), (24, 12)], fill=BRASS_DK, width=2)
    d.line([(34, 24), (40, 12)], fill=BRASS_DK, width=2)
    circle(d, 24, 12, 2, WISP)
    circle(d, 40, 12, 2, WISP)
    return img


def creature_wickmoth() -> Image.Image:
    img = rgba((64, 64))
    d = ImageDraw.Draw(img)
    soot = (70, 58, 40, 255)
    d.ellipse([4, 16, 32, 48], fill=(90, 72, 42, 230))
    d.ellipse([32, 16, 60, 48], fill=(90, 72, 42, 230))
    d.ellipse([24, 22, 40, 48], fill=soot)
    d.ellipse([28, 26, 36, 34], fill=(244, 180, 90, 255))
    d.polygon([(20, 50), (28, 58), (24, 50)], fill=(180, 80, 40, 200))
    d.polygon([(44, 50), (36, 58), (40, 50)], fill=(180, 80, 40, 200))
    d.line([(30, 22), (22, 8)], fill=soot, width=2)
    d.line([(34, 22), (42, 8)], fill=soot, width=2)
    return img


def creature_cobbleback() -> Image.Image:
    img = rgba((64, 64))
    d = ImageDraw.Draw(img)
    # stacked cobbles
    blocks = [
        (14, 28, 50, 50, (90, 96, 108, 255)),
        (18, 16, 46, 34, (107, 114, 128, 255)),
        (24, 8, 40, 22, (130, 136, 148, 255)),
    ]
    for x0, y0, x1, y1, c in blocks:
        d.rounded_rectangle([x0, y0, x1, y1], radius=4, fill=c, outline=(40, 44, 52, 255), width=2)
    # nail heads
    for p in ((22, 36), (32, 40), (42, 36), (28, 24), (36, 24)):
        circle(d, p[0], p[1], 3, (160, 150, 130, 255), (40, 40, 40, 255), 1)
    # legs
    for x in (18, 28, 36, 46):
        d.rectangle([x, 50, x + 3, 58], fill=(70, 74, 84, 255))
    return img


def creature_nailbit() -> Image.Image:
    img = rgba((64, 64))
    d = ImageDraw.Draw(img)
    wire = (160, 164, 172, 255)
    # zigzag body
    pts = [(8, 40), (16, 20), (24, 44), (32, 16), (40, 46), (48, 22), (56, 40)]
    d.line(pts, fill=wire, width=5, joint="curve")
    d.line(pts, fill=IRON, width=2)
    # head bite
    d.polygon([(48, 18), (62, 14), (58, 28), (50, 24)], fill=(180, 184, 192, 255), outline=(40, 40, 48))
    d.polygon([(56, 16), (62, 14), (60, 20)], fill=(40, 40, 48, 255))  # tooth
    circle(d, 52, 20, 2, (20, 20, 24, 255))
    # filings
    for p in ((12, 48), (20, 52), (36, 54), (28, 8)):
        d.point(p, fill=wire)
        d.rectangle([p[0], p[1], p[0] + 2, p[1] + 1], fill=GOLD)
    return img


def creature_briarseed() -> Image.Image:
    img = rgba((64, 64))
    d = ImageDraw.Draw(img)
    # seed hull
    d.ellipse([16, 16, 48, 50], fill=BLOOM, outline=(28, 50, 26, 255), width=2)
    d.ellipse([22, 22, 42, 42], fill=(92, 140, 70, 255))
    d.ellipse([26, 26, 34, 34], fill=(40, 70, 36, 255))
    # thorns
    cx, cy = 32, 33
    for i in range(8):
        a = math.radians(-90 + i * 45)
        x0, y0 = cx + 14 * math.cos(a), cy + 16 * math.sin(a)
        x1, y1 = cx + 24 * math.cos(a), cy + 26 * math.sin(a)
        ox, oy = -6 * math.sin(a), 6 * math.cos(a)
        d.polygon([(x0, y0), (x1, y1), (x0 + ox * 0.15, y0 + oy * 0.15)], fill=(48, 80, 40, 255))
    # root toes
    d.line([(24, 48), (18, 60)], fill=(90, 70, 40, 255), width=3)
    d.line([(32, 50), (32, 60)], fill=(90, 70, 40, 255), width=3)
    d.line([(40, 48), (46, 60)], fill=(90, 70, 40, 255), width=3)
    return img


def creature_marrowl() -> Image.Image:
    img = rgba((64, 64))
    d = ImageDraw.Draw(img)
    bone = (220, 214, 200, 255)
    dusk_w = (70, 50, 110, 255)
    # wings
    d.polygon([(32, 28), (6, 22), (10, 48), (28, 40)], fill=dusk_w)
    d.polygon([(32, 28), (58, 22), (54, 48), (36, 40)], fill=dusk_w)
    # body
    d.ellipse([22, 22, 42, 52], fill=bone, outline=DUSK, width=2)
    # head diamond
    d.polygon([(32, 6), (46, 22), (32, 30), (18, 22)], fill=bone, outline=DUSK, width=2)
    # eye spots
    circle(d, 26, 20, 4, DUSK)
    circle(d, 38, 20, 4, DUSK)
    circle(d, 26, 20, 2, (220, 200, 120, 255))
    circle(d, 38, 20, 2, (220, 200, 120, 255))
    d.polygon([(32, 24), (36, 28), (32, 30), (28, 28)], fill=(40, 30, 50, 255))
    return img


def creature_veilcrawler() -> Image.Image:
    img = rgba((64, 64))
    d = ImageDraw.Draw(img)
    veil = (70, 50, 120, 230)
    # long body S
    segments = [(12, 48), (18, 36), (24, 42), (30, 28), (36, 34), (44, 18), (50, 22)]
    r = 10
    for (x, y) in segments:
        d.ellipse([x - r, y - r + 2, x + r, y + r], fill=veil)
        r = max(5, r - 1)
    # shroud fringe
    for x in range(8, 30, 4):
        d.line([(x, 52), (x - 2, 62)], fill=(40, 24, 70, 200), width=2)
    # face
    circle(d, 50, 18, 7, (90, 70, 140, 255), (20, 12, 40, 255), 1)
    circle(d, 48, 17, 2, WISP)
    circle(d, 54, 17, 2, WISP)
    return img


def creature_brinekit() -> Image.Image:
    img = rgba((64, 64))
    d = ImageDraw.Draw(img)
    body = TIDE
    hi = (40, 130, 140, 255)
    # kit body
    d.ellipse([16, 18, 50, 50], fill=body)
    d.ellipse([22, 24, 44, 42], fill=hi)
    # gill frills
    d.polygon([(16, 28), (6, 24), (8, 34), (16, 32)], fill=(80, 160, 150, 255))
    d.polygon([(16, 36), (6, 38), (8, 46), (18, 40)], fill=(80, 160, 150, 255))
    d.polygon([(48, 28), (58, 24), (56, 34), (48, 32)], fill=(80, 160, 150, 255))
    # pouch
    d.ellipse([26, 36, 40, 52], fill=(20, 90, 100, 255), outline=(10, 40, 50, 255))
    d.ellipse([30, 40, 36, 48], fill=(180, 220, 220, 180))
    # face
    circle(d, 28, 28, 2, (10, 20, 24, 255))
    circle(d, 38, 28, 2, (10, 20, 24, 255))
    d.arc([28, 30, 38, 38], 20, 160, fill=(10, 30, 34, 255), width=2)
    # ears
    d.polygon([(22, 20), (18, 8), (28, 18)], fill=body)
    d.polygon([(42, 20), (46, 8), (36, 18)], fill=body)
    return img


def main():
    save(tile_floor(False), "tiles/floor.png")
    save(tile_floor(True), "tiles/floor_alt.png")
    save(tile_wall(), "tiles/wall.png")
    save(tile_stairs(), "tiles/stairs.png")

    save(icon_pentagon(WISP, "W"), "ui/icon_wisp.png")
    save(icon_pentagon(IRON, "I"), "ui/icon_iron.png")
    save(icon_pentagon(BLOOM, "B"), "ui/icon_bloom.png")
    save(icon_pentagon(DUSK, "D"), "ui/icon_dusk.png")
    save(icon_pentagon(TIDE, "T"), "ui/icon_tide.png")

    save(wordmark(), "ui/wordmark.png")
    save(hp_frame(), "ui/hp_frame.png")
    save(hp_fill(), "ui/hp_fill.png")
    save(btn_panel(), "ui/btn_panel.png")

    for facing in ("down", "up", "left", "right"):
        save(player_dir(facing), f"player/delver_idle_{facing}.png")

    save(creature_glimmerling(), "creatures/glimmerling.png")
    save(creature_cobbleback(), "creatures/cobbleback.png")
    save(creature_briarseed(), "creatures/briarseed.png")
    save(creature_marrowl(), "creatures/marrowl.png")
    save(creature_brinekit(), "creatures/brinekit.png")
    save(creature_wickmoth(), "creatures/wickmoth.png")
    save(creature_nailbit(), "creatures/nailbit.png")
    save(creature_veilcrawler(), "creatures/veilcrawler.png")

    save(icon_png(), "ui/icon.png")
    # project icon at root
    icon_png().save(ROOT / "icon.png", "PNG")
    print("wrote icon.png")


if __name__ == "__main__":
    main()
