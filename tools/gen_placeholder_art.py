"""Erzeugt die Platzhalter-Grafiken für M1.

    python tools/gen_placeholder_art.py

Reproduzierbar und versioniert, damit die Platzhalter nicht als Binärmüll
im Repo liegen, sondern jederzeit neu erzeugt werden können. Sobald echte
Assets aus der Art-Pipeline (PLAN.md §3) kommen, ersetzen sie diese Dateien
Stück für Stück — die Tile-Geometrie bleibt dieselbe.

Tile-Anatomie (verbindlich, siehe PLAN.md §2.5):
    Diamant-Oberseite  128 x 64  (2:1-Projektion)
    Seitenfläche       20 px nach unten
    Texturgröße        128 x 84
"""

from __future__ import annotations

import os
from PIL import Image, ImageDraw

# --- Verbindliche Maße ---
TILE_W = 128
TILE_H = 64
SIDE_H = 20
TEX_H = TILE_H + SIDE_H

# Supersampling für saubere Diagonalen — PIL zeichnet Polygone ohne
# Kantenglättung, deshalb 4x groß zeichnen und herunterskalieren.
SS = 4

OUT_TILES = "assets/art/tiles/board_tiles.png"
OUT_PAWNS = "assets/art/characters/pawns.png"

# --- Palette ---
# Bewusst klein gehalten. Das echte Art Bible (PLAN.md §3.1) legt später
# 24-32 Farben fest; hier reicht eine Farbe je Feldtyp.
TILE_TYPES = [
    ("normal", (74, 144, 217)),
    ("bonus", (245, 197, 24)),
    ("falle", (229, 72, 77)),
    ("stern", (168, 85, 247)),
    ("start", (74, 222, 128)),
    ("deko", (45, 106, 79)),
]

PAWN_COLORS = [
    (239, 68, 68),
    (59, 130, 246),
    (250, 204, 21),
    (34, 197, 94),
]

OUTLINE = (27, 27, 47)


def shade(color: tuple[int, int, int], factor: float) -> tuple[int, int, int]:
    """Licht kommt von oben-links — Seitenflächen entsprechend abdunkeln."""
    return tuple(max(0, min(255, int(c * factor))) for c in color)


def star_points(cx: float, cy: float, outer: float, inner: float, n: int = 5):
    import math

    pts = []
    for i in range(n * 2):
        r = outer if i % 2 == 0 else inner
        a = -math.pi / 2 + i * math.pi / n
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def draw_tile(draw: ImageDraw.ImageDraw, ox: int, name: str, color) -> None:
    """Zeichnet ein Tile bei x-Offset ox (bereits in Supersampling-Skala)."""
    w, h, s = TILE_W * SS, TILE_H * SS, SIDE_H * SS
    lw = max(1, 2 * SS)

    top = [(ox + w // 2, 0), (ox + w, h // 2), (ox + w // 2, h), (ox, h // 2)]
    left = [(ox, h // 2), (ox + w // 2, h), (ox + w // 2, h + s), (ox, h // 2 + s)]
    right = [
        (ox + w // 2, h),
        (ox + w, h // 2),
        (ox + w, h // 2 + s),
        (ox + w // 2, h + s),
    ]

    # Deko-Tiles sind reine Grundfläche ohne Seitenwände (Gras/Wasser).
    if name != "deko":
        draw.polygon(left, fill=shade(color, 0.55), outline=OUTLINE, width=lw)
        draw.polygon(right, fill=shade(color, 0.72), outline=OUTLINE, width=lw)

    draw.polygon(top, fill=color, outline=OUTLINE, width=lw)

    # Symbol auf der Oberseite — auf kleinen Displays ist Farbe allein
    # nicht unterscheidbar genug, und für den Farbenblind-Modus
    # (PLAN.md M6) brauchen wir ohnehin eine zweite Kodierung.
    cx, cy = ox + w // 2, h // 2
    sym = shade(color, 0.4)
    r = 11 * SS

    if name == "bonus":
        bar = 4 * SS
        draw.rectangle([cx - r, cy - bar, cx + r, cy + bar], fill=sym)
        draw.rectangle([cx - bar, cy - r, cx + bar, cy + r], fill=sym)
    elif name == "falle":
        bar = 4 * SS
        draw.rectangle([cx - r, cy - bar, cx + r, cy + bar], fill=sym)
    elif name == "stern":
        draw.polygon(star_points(cx, cy, r * 1.3, r * 0.55), fill=sym)
    elif name == "start":
        draw.polygon(
            [(cx - r, cy + r * 0.7), (cx + r, cy), (cx - r, cy - r * 0.7)], fill=sym
        )
    elif name == "normal":
        draw.ellipse([cx - r * 0.4, cy - r * 0.4, cx + r * 0.4, cy + r * 0.4], fill=sym)


def gen_tiles() -> None:
    n = len(TILE_TYPES)
    img = Image.new("RGBA", (TILE_W * n * SS, TEX_H * SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    for i, (name, color) in enumerate(TILE_TYPES):
        draw_tile(draw, i * TILE_W * SS, name, color)

    img = img.resize((TILE_W * n, TEX_H), Image.LANCZOS)
    os.makedirs(os.path.dirname(OUT_TILES), exist_ok=True)
    img.save(OUT_TILES)
    print(f"{OUT_TILES}  {img.width}x{img.height}  ({n} Tiles a {TILE_W}x{TEX_H})")


def gen_pawns() -> None:
    """Spielfiguren: Kegel mit Kugel. Silhouette muss auf 6\" lesbar sein."""
    pw, ph = 48, 72
    n = len(PAWN_COLORS)
    img = Image.new("RGBA", (pw * n * SS, ph * SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    lw = max(1, 2 * SS)

    for i, color in enumerate(PAWN_COLORS):
        ox = i * pw * SS
        cx = ox + (pw * SS) // 2

        # Schatten am Boden — verankert die Figur optisch auf dem Tile.
        draw.ellipse(
            [ox + 8 * SS, (ph - 16) * SS, ox + (pw - 8) * SS, (ph - 4) * SS],
            fill=(0, 0, 0, 70),
        )
        # Körper
        draw.polygon(
            [
                (cx, 22 * SS),
                (ox + (pw - 9) * SS, (ph - 12) * SS),
                (ox + 9 * SS, (ph - 12) * SS),
            ],
            fill=color,
            outline=OUTLINE,
            width=lw,
        )
        # Kopf
        draw.ellipse(
            [cx - 13 * SS, 4 * SS, cx + 13 * SS, 30 * SS],
            fill=shade(color, 1.15),
            outline=OUTLINE,
            width=lw,
        )
        # Glanzpunkt, Licht von oben-links
        draw.ellipse(
            [cx - 9 * SS, 8 * SS, cx - 2 * SS, 15 * SS], fill=(255, 255, 255, 150)
        )

    img = img.resize((pw * n, ph), Image.LANCZOS)
    os.makedirs(os.path.dirname(OUT_PAWNS), exist_ok=True)
    img.save(OUT_PAWNS)
    print(f"{OUT_PAWNS}  {img.width}x{img.height}  ({n} Figuren a {pw}x{ph})")


if __name__ == "__main__":
    gen_tiles()
    gen_pawns()
