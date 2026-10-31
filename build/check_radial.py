"""Check the RADIAL ring dumped by tb_render_pipeline.v against a reference model.

The model follows the written geometry (docs/AUDIO_VISUAL_3.0.md, section 8)
rather than the RTL structure: 48 sectors of 7.5 degrees centred on XGA pixel
(884, 628), inner radius 45, outer radius 54 + 3h/8, 1.5 px spoke gaps,
1/8-pixel coverage from signed edge distances (outer arc via 65536/R), and a radial gradient.
Writes docs/preview/radial_before_after.png from radial_preview.hex.
"""
from math import cos, sin, radians
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
CX, CY, BOX = 884, 628, 96
SPOKES = [(round(256 * cos(radians(7.5 * k))), round(256 * sin(radians(7.5 * k)))) for k in range(1, 6)]
INNER, INNER2 = 45, 45 * 45
HALF_GAP = 192  # 0.75 px in 1/256 px
INNER_RGB, OUTER_RGB = (0x25, 0x8D, 0xB8), (0x86, 0xE9, 0xF4)


def cover(value4: int, step: int) -> int:
    """Eighths of a pixel inside an edge: value4 = 4 * distance * step."""
    return sum(value4 >= (k - 4) * step for k in range(1, 9))


def ring(X: int, Y: int, bg: tuple, heights: list) -> tuple:
    ax, ay = abs(X - CX), abs(Y - CY)
    if ax >= BOX or ay >= BOX:
        return bg
    major, minor = max(ax, ay), min(ax, ay)
    s = [minor * c - major * n for c, n in SPOKES]
    cell = sum(v >= 0 for v in s)                      # 0..5 inside the octant
    quadrant = 11 - cell if ax < ay else cell
    right, bottom = X >= CX, Y >= CY
    sector = (quadrant if bottom else 47 - quadrant) if right else (23 - quadrant if bottom else 24 + quadrant)
    radius = 54 + (3 * heights[sector % 16] >> 3)
    lower = minor * 256 if cell == 0 else s[cell - 1]
    upper = (major - minor) * 181 if cell == 5 else -s[cell]
    dist = min(lower, upper)
    gap = min(8, max(0, (dist - (HALF_GAP - 128)) >> 5))
    r2 = ax * ax + ay * ay
    # Outer arc: 8d = 4(R^2-r^2)/R via a rounded reciprocal, saturated at |R^2-r^2| = 128.
    delta = max(-128, min(127, radius * radius - r2))
    outer = max(0, min(8, (delta * round(65536 / radius) >> 14) + 4))
    alpha = min(outer, cover(4 * (r2 - INNER2), INNER), gap)
    if alpha == 0:
        return bg
    t = 0 if r2 < INNER2 else min(95, (r2 - INNER2) >> 6)
    deltas = (131, 124, 81)  # (outer - inner) * 128 / 95
    colour = [base + (t * d >> 7) for base, d in zip(INNER_RGB, deltas)]
    assert all(c == o for c, o in zip([base + (95 * d >> 7) for base, d in zip(INNER_RGB, deltas)], OUTER_RGB))
    return tuple(b + ((c - b) * alpha >> 3) for b, c in zip(bg, colour))


def rgb(word: str) -> tuple:
    v = int(word, 16)
    return (v >> 16, v >> 8 & 255, v & 255)


def main() -> int:
    lines = (HERE / "radial_rtl.hex").read_text().split()
    pairs = list(zip(lines[0::2], lines[1::2]))
    box = [(X, Y) for Y in range(CY - 95, CY + 96) for X in range(CX - 95, CX + 96)]
    assert len(pairs) == 3 * len(box), len(pairs)
    blended = 0
    for frame in range(3):
        heights = [(m * 13 + frame * 31) % 97 for m in range(16)]
        for (X, Y), (bg, out) in zip(box, pairs[frame * len(box):(frame + 1) * len(box)]):
            want = ring(X, Y, rgb(bg), heights)
            if rgb(out) != want:
                print(f"RADIAL_MODEL_MISMATCH frame {frame} ({X},{Y}) rtl {out} model {want}")
                return 1
            blended += rgb(out) != rgb(bg)
    print(f"RADIAL_RTL_EQUALS_MODEL_{len(pairs)}_PIXELS_{blended}_BLENDED_PASS")

    from PIL import Image, ImageDraw
    words = (HERE / "radial_preview.hex").read_text().split()
    before, after = Image.new("RGB", (200, 200)), Image.new("RGB", (200, 200))
    for i in range(200 * 200):
        before.putpixel((i % 200, i // 200), rgb(words[2 * i]))
        after.putpixel((i % 200, i // 200), rgb(words[2 * i + 1]))
    zoom = 3
    sheet = Image.new("RGB", (400 * zoom + 30, 200 * zoom + 30), (20, 20, 20))
    sheet.paste(before.resize((200 * zoom, 200 * zoom), Image.NEAREST), (10, 25))
    sheet.paste(after.resize((200 * zoom, 200 * zoom), Image.NEAREST), (200 * zoom + 20, 25))
    draw = ImageDraw.Draw(sheet)
    draw.text((10, 6), "3.0: 640x480 grid, 1.6x pixel repeat, hard edges", fill=(255, 220, 0))
    draw.text((200 * zoom + 20, 6), "now: native XGA, 7.5 deg sectors, 1/8 px antialiasing", fill=(255, 220, 0))
    out = HERE.parent / "docs" / "preview" / "radial_before_after.png"
    sheet.save(out)
    print(f"wrote {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
