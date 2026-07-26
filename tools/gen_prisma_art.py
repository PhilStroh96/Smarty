"""Erzeugt die Prisma-Assets (Flat-Vektor) — siehe docs/art-bible.md.

    python tools/gen_prisma_art.py

Flat-Vektor lässt sich prozedural nahezu final erzeugen: pixelgenau,
versionierbar, keine KI-Konsistenzprobleme. Tiefe kommt aus Kantenlicht und
2-Ton-Seitenschattierung, nicht aus Verläufen oder Texturen.

Erzeugt:
- assets/art/tiles/board_tiles.png    6 Tiles (128x84), flach + Kantenlicht
- assets/art/characters/pawns.png     4 Figuren (48x72) mit Kopfformen
- assets/art/fx/board_shadow.png      weicher Schatten zur Erdung des Bretts
"""

from __future__ import annotations

import math
import os
from PIL import Image, ImageDraw, ImageFilter

# --- Verbindliche Maße (Art Bible) ---
TILE_W, TILE_H, SIDE_H = 128, 64, 20
TEX_H = TILE_H + SIDE_H
SS = 4  # Supersampling gegen Treppchen an den Diagonalen

OUT_TILES = "assets/art/tiles/board_tiles.png"
OUT_PAWNS = "assets/art/characters/pawns.png"
OUT_SHADOW = "assets/art/fx/board_shadow.png"

OUTLINE = (0x14, 0x17, 0x33)

# Reihenfolge muss zu TileTypes.ATLAS_INDEX passen.
TILE_TYPES = [
    ("normal", (0x3E, 0x8E, 0xF7)),
    ("bonus", (0xF6, 0xA8, 0x21)),
    ("falle", (0xEE, 0x4B, 0x44)),
    ("stern", (0x9B, 0x6B, 0xFF)),
    ("start", (0x2F, 0xD9, 0x8A)),
    ("deko", (0x24, 0x2A, 0x54)),
]

PAWN_COLORS = [(0xFF, 0x4D, 0x5E), (0x2E, 0x9B, 0xFF), (0xFF, 0xC9, 0x3C), (0x1F, 0xB3, 0x6B)]


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)


def lighten(c, f):
    return tuple(max(0, min(255, int(v + (255 - v) * f))) for v in c)


def star_pts(cx, cy, outer, inner, n=5):
    pts = []
    for i in range(n * 2):
        r = outer if i % 2 == 0 else inner
        a = -math.pi / 2 + i * math.pi / n
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


# ---------------------------------------------------------------------------
# Tiles
# ---------------------------------------------------------------------------

def draw_tile(draw, ox, name, color):
    w, h, s = TILE_W * SS, TILE_H * SS, SIDE_H * SS
    lw = 2 * SS

    top = [(ox + w // 2, 0), (ox + w, h // 2), (ox + w // 2, h), (ox, h // 2)]
    left = [(ox, h // 2), (ox + w // 2, h), (ox + w // 2, h + s), (ox, h // 2 + s)]
    right = [(ox + w // 2, h), (ox + w, h // 2), (ox + w, h // 2 + s), (ox + w // 2, h + s)]

    if name == "deko":
        # Reiner Untergrund ohne Wände.
        draw.polygon(top, fill=color, outline=OUTLINE, width=lw)
        return

    # Wände zuerst (hinten). Licht oben-links: links dunkler als rechts.
    draw.polygon(left, fill=shade(color, 0.62), outline=OUTLINE, width=lw)
    draw.polygon(right, fill=shade(color, 0.78), outline=OUTLINE, width=lw)

    # Flache Oberseite mit Kontur.
    draw.polygon(top, fill=color, outline=OUTLINE, width=lw)

    # Kantenlicht auf den beiden OBEREN Kanten (Prisma-Signature).
    hi = lighten(color, 0.30)
    hw = max(2, int(2.5 * SS))
    draw.line([top[3], top[0]], fill=hi, width=hw)   # links -> oben
    draw.line([top[0], top[1]], fill=hi, width=hw)   # oben -> rechts

    _draw_symbol(draw, name, color, ox + w // 2, h // 2)


def _draw_symbol(draw, name, color, cx, cy):
    sym = shade(color, 0.40)
    r = 11 * SS
    lw = 4 * SS
    if name == "bonus":
        draw.line([(cx - r, cy), (cx + r, cy)], fill=sym, width=lw)
        draw.line([(cx, cy - r), (cx, cy + r)], fill=sym, width=lw)
    elif name == "falle":
        draw.line([(cx - r, cy), (cx + r, cy)], fill=sym, width=lw)
    elif name == "stern":
        draw.polygon(star_pts(cx, cy, r * 1.25, r * 0.52), fill=sym)
    elif name == "start":
        draw.polygon([(cx - r * 0.7, cy - r * 0.8), (cx + r * 0.9, cy),
                      (cx - r * 0.7, cy + r * 0.8)], fill=sym)
    else:  # normal
        rr = 4 * SS
        draw.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=sym)


def gen_tiles():
    n = len(TILE_TYPES)
    img = Image.new("RGBA", (TILE_W * n * SS, TEX_H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i, (name, color) in enumerate(TILE_TYPES):
        draw_tile(d, i * TILE_W * SS, name, color)
    img = img.resize((TILE_W * n, TEX_H), Image.LANCZOS)
    os.makedirs(os.path.dirname(OUT_TILES), exist_ok=True)
    img.save(OUT_TILES)
    print(f"{OUT_TILES}  {img.width}x{img.height}")


# ---------------------------------------------------------------------------
# Figuren — flach, mit Kopfform zur Unterscheidung (Barrierefreiheit)
# ---------------------------------------------------------------------------

PW, PH = 48, 72


def _head_accessory(d, player, cx, top_y, color):
    """Eindeutige Kopfform je Spieler — auch ohne Farbe unterscheidbar."""
    lw = 2 * SS
    dark = OUTLINE
    if player == 0:  # Krönchen
        c = lighten(color, 0.25)
        y = top_y
        pts = [(cx - 11 * SS, y), (cx - 5 * SS, y - 9 * SS), (cx, y),
               (cx + 5 * SS, y - 9 * SS), (cx + 11 * SS, y)]
        d.polygon(pts, fill=c, outline=dark, width=lw)
    elif player == 1:  # Cap mit Schirm
        c = lighten(color, 0.18)
        d.pieslice([cx - 12 * SS, top_y - 12 * SS, cx + 12 * SS, top_y + 12 * SS],
                   180, 360, fill=c, outline=dark, width=lw)
        d.ellipse([cx + 2 * SS, top_y - 2 * SS, cx + 20 * SS, top_y + 4 * SS],
                  fill=c, outline=dark, width=lw)
    elif player == 2:  # Antenne mit Bommel
        d.line([(cx, top_y), (cx, top_y - 12 * SS)], fill=dark, width=lw)
        rr = 5 * SS
        d.ellipse([cx - rr, top_y - 12 * SS - rr, cx + rr, top_y - 12 * SS + rr],
                  fill=lighten(color, 0.3), outline=dark, width=lw)
    else:  # Blatt
        c = lighten(color, 0.2)
        d.polygon([(cx, top_y + 2 * SS), (cx + 12 * SS, top_y - 8 * SS),
                   (cx + 2 * SS, top_y - 12 * SS)], fill=c, outline=dark, width=lw)


def draw_pawn(d, ox, player, color):
    lw = 2 * SS
    cx = ox + (PW * SS) // 2

    # Kontaktschatten.
    d.ellipse([ox + 7 * SS, (PH - 15) * SS, ox + (PW - 7) * SS, (PH - 3) * SS],
              fill=(0x0A, 0x0C, 0x1E, 90))

    # Körper: Kegelstumpf mit weichen Ecken (6-Punkt-Silhouette).
    top_y, bot_y = 30 * SS, (PH - 8) * SS
    tw, bw = 10 * SS, 16 * SS
    body = [(cx - tw, top_y), (cx + tw, top_y),
            (cx + bw, bot_y - 3 * SS), (cx + bw - 3 * SS, bot_y),
            (cx - bw + 3 * SS, bot_y), (cx - bw, bot_y - 3 * SS)]
    d.polygon(body, fill=color, outline=OUTLINE, width=lw)
    # Kantenlicht links.
    d.line([(cx - tw, top_y + 2 * SS), (cx - bw, bot_y - 5 * SS)],
           fill=lighten(color, 0.28), width=max(2, 2 * SS))

    # Kopf.
    hr = 13 * SS
    hy = 16 * SS
    d.ellipse([cx - hr, hy - hr, cx + hr, hy + hr],
              fill=color, outline=OUTLINE, width=lw)
    # Glanz oben-links.
    d.ellipse([cx - 9 * SS, hy - 10 * SS, cx - 2 * SS, hy - 3 * SS],
              fill=lighten(color, 0.45))
    # Augen.
    for ex in (-5 * SS, 5 * SS):
        d.ellipse([cx + ex - 3 * SS, hy - 2 * SS, cx + ex + 3 * SS, hy + 4 * SS], fill=(255, 255, 255))
        d.ellipse([cx + ex - 1 * SS, hy, cx + ex + 2 * SS, hy + 3 * SS], fill=OUTLINE)

    _head_accessory(d, player, cx, hy - hr, color)


def gen_pawns():
    n = len(PAWN_COLORS)
    img = Image.new("RGBA", (PW * n * SS, PH * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i, color in enumerate(PAWN_COLORS):
        draw_pawn(d, i * PW * SS, i, color)
    img = img.resize((PW * n, PH), Image.LANCZOS)
    os.makedirs(os.path.dirname(OUT_PAWNS), exist_ok=True)
    img.save(OUT_PAWNS)
    print(f"{OUT_PAWNS}  {img.width}x{img.height}")


# ---------------------------------------------------------------------------
# Brett-Schatten (weiche Ellipse zur Erdung)
# ---------------------------------------------------------------------------

def gen_shadow():
    w, h = 512, 288
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([40, 60, w - 40, h - 60], fill=(0x08, 0x0A, 0x18, 150))
    img = img.filter(ImageFilter.GaussianBlur(38))
    os.makedirs(os.path.dirname(OUT_SHADOW), exist_ok=True)
    img.save(OUT_SHADOW)
    print(f"{OUT_SHADOW}  {img.width}x{img.height}")


if __name__ == "__main__":
    gen_tiles()
    gen_pawns()
    gen_shadow()
