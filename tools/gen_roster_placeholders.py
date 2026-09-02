#!/usr/bin/env python3
"""64x64 geometric placeholders for the 162 NEW roster creatures. Never overwrite the original 8."""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "art" / "creatures"
DATA = ROOT / "data"

PROTECTED = {
    "glimmerling", "wickmoth", "cobbleback", "nailbit",
    "briarseed", "marrowl", "veilcrawler", "brinekit",
}

SHAPES = ("circle", "diamond", "moth", "beetle", "hound", "wyrm", "shard")


def hex_rgba(h: str, a: int = 255) -> tuple[int, int, int, int]:
    h = h.lstrip("#")
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return (r, g, b, a)


def shape_for(cid: str) -> str:
    n = cid.lower()
    if any(x in n for x in ("moth", "wisp", "cowl")):
        return "moth"
    if any(x in n for x in ("beetle", "mite", "tick", "urn", "cap")):
        return "beetle"
    if any(x in n for x in ("hound", "kit", "pup", "whelp", "lynx", "lion")):
        return "hound"
    if any(x in n for x in ("wyrm", "eel", "snake", "worm", "drake", "serpent")):
        return "wyrm"
    if any(x in n for x in ("shard", "crystal", "prism", "glyph", "rune", "sigil", "ley")):
        return "shard"
    if any(x in n for x in ("mote", "ling", "orb", "heart", "soul")):
        return "circle"
    h = int(hashlib.md5(cid.encode()).hexdigest()[:8], 16)
    return SHAPES[h % len(SHAPES)]


def glow(size, cx, cy, r, color, steps=6):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cr, cg, cb = color[:3]
    for i in range(steps, 0, -1):
        a = int(14 + 22 * (i / steps))
        rr = int(r * i / steps)
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=(cr, cg, cb, a))
    return layer.filter(ImageFilter.GaussianBlur(1.6))


def draw_creature(cid: str, types: list[str], colors: dict) -> Image.Image:
    primary = types[0]
    fill = hex_rgba(colors[primary])
    accent = hex_rgba(colors[types[1]]) if len(types) > 1 else tuple(min(255, c + 40) if i < 3 else 255 for i, c in enumerate(fill))
    outline = (18, 16, 22, 230)
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    shape = shape_for(cid)
    img = Image.alpha_composite(img, glow((64, 64), 32, 34, 20, fill, 5))
    d = ImageDraw.Draw(img)
    cx, cy = 32, 34

    if shape == "circle":
        d.ellipse([14, 16, 50, 52], fill=fill, outline=outline, width=2)
        d.ellipse([22, 22, 42, 42], fill=accent)
        d.ellipse([28, 26, 34, 32], fill=outline)
    elif shape == "diamond":
        d.polygon([(32, 8), (54, 34), (32, 58), (10, 34)], fill=fill, outline=outline)
        d.polygon([(32, 18), (44, 34), (32, 48), (20, 34)], fill=accent)
        d.ellipse([29, 30, 35, 36], fill=outline)
    elif shape == "moth":
        d.polygon([(32, 28), (8, 12), (10, 40), (28, 36)], fill=fill, outline=outline)
        d.polygon([(32, 28), (56, 12), (54, 40), (36, 36)], fill=fill, outline=outline)
        d.ellipse([24, 22, 40, 48], fill=accent, outline=outline, width=1)
        d.ellipse([28, 26, 34, 32], fill=outline)
        d.line([(30, 22), (24, 10)], fill=outline, width=2)
        d.line([(34, 22), (40, 10)], fill=outline, width=2)
        d.ellipse([22, 8, 26, 12], fill=accent)
        d.ellipse([38, 8, 42, 12], fill=accent)
    elif shape == "beetle":
        d.rounded_rectangle([16, 18, 48, 48], radius=10, fill=fill, outline=outline, width=2)
        d.ellipse([22, 22, 42, 38], fill=accent)
        for x in (18, 28, 38, 46):
            d.rectangle([x, 46, x + 3, 56], fill=outline)
        d.ellipse([26, 26, 32, 32], fill=outline)
        d.ellipse([34, 26, 40, 32], fill=outline)
    elif shape == "hound":
        d.ellipse([14, 22, 52, 50], fill=fill, outline=outline, width=2)
        d.polygon([(46, 28), (60, 24), (56, 38), (46, 36)], fill=fill, outline=outline)
        d.polygon([(20, 22), (14, 8), (28, 20)], fill=fill, outline=outline)
        d.polygon([(36, 20), (42, 8), (30, 20)], fill=fill, outline=outline)
        d.ellipse([22, 28, 42, 42], fill=accent)
        d.ellipse([24, 30, 30, 36], fill=outline)
        d.ellipse([34, 30, 40, 36], fill=outline)
        d.ellipse([18, 46, 26, 56], fill=outline)
        d.ellipse([38, 46, 46, 56], fill=outline)
    elif shape == "wyrm":
        segs = [(14, 48), (20, 36), (28, 42), (36, 26), (44, 32), (52, 16)]
        r = 11
        for (x, y) in segs:
            d.ellipse([x - r, y - r, x + r, y + r], fill=fill, outline=outline)
            r = max(5, r - 1)
        d.ellipse([48, 10, 60, 22], fill=accent, outline=outline)
        d.ellipse([52, 13, 56, 17], fill=outline)
    else:  # shard
        h = int(hashlib.md5(cid.encode()).hexdigest()[8:16], 16)
        jitter = [((h >> (i * 3)) % 7) - 3 for i in range(6)]
        pts = [
            (32 + jitter[0], 6),
            (54 + jitter[1], 22),
            (48 + jitter[2], 56),
            (32 + jitter[3], 48),
            (14 + jitter[4], 56),
            (10 + jitter[5], 20),
        ]
        d.polygon(pts, fill=fill, outline=outline)
        d.polygon([(32, 16), (42, 34), (32, 44), (22, 34)], fill=accent)
        d.ellipse([29, 30, 35, 36], fill=outline)

    # tiny type pip
    d.ellipse([4, 4, 14, 14], fill=fill, outline=outline)
    if len(types) > 1:
        d.ellipse([50, 4, 60, 14], fill=accent, outline=outline)
    return img


def main() -> None:
    types = json.loads((DATA / "types.json").read_text())
    colors = types["colors"]
    creatures = json.loads((DATA / "creatures.json").read_text())
    ART.mkdir(parents=True, exist_ok=True)
    n = 0
    skipped = 0
    for cid, c in creatures.items():
        dest = ART / f"{cid}.png"
        if cid in PROTECTED or dest.exists():
            skipped += 1
            continue
        img = draw_creature(cid, c["types"], colors)
        img.save(dest, "PNG")
        n += 1
    print(f"wrote {n} placeholders, skipped existing/protected {skipped}")


if __name__ == "__main__":
    main()
