"""Generates the WUUT app icon.

    python3 -m pip install Pillow
    python3 scripts/make_icon.py

Writes WUUT/Assets.xcassets/AppIcon.appiconset/icon-1024.png. The icon is generated
rather than hand-drawn so it can be regenerated if the palette moves — the colours below
must stay in step with `Theme` in WUUT/Shared/Theme.swift.

A page of writing with one line struck out. Four lines, because an hour is four quarter
hours; three are ink, one is the violet redaction the app uses for time you failed to
account for. The whole product in one glance.

Drawn at 4x and downsampled — Pillow does not antialias — and saved without an alpha
channel, which iOS requires of app icons.
"""
import math
from PIL import Image, ImageDraw

SS = 4
SIZE = 1024

PAPER      = (247, 241, 222)
PAPER_EDGE = (240, 232, 208)
RULE       = (192, 174, 204)
INK        = (30, 26, 19)
VIOLET     = (84, 38, 143)

def hatched(draw, box, colour, spacing, width):
    x0, y0, x1, y1 = box
    h = y1 - y0
    for x in range(int(x0 - h), int(x1), spacing):
        draw.line([(x, y1), (x + h, y0)], fill=colour, width=width)

def render(size=SIZE):
    s = size * SS
    img = Image.new("RGB", (s, s), PAPER)
    d = ImageDraw.Draw(img)

    # A whisper of tone so the page is not a flat fill.
    for y in range(s):
        t = y / (s - 1)
        d.line([(0, y), (s, y)],
               fill=tuple(round(a + (b - a) * t) for a, b in zip(PAPER, PAPER_EDGE)))

    margin = int(s * 0.145)
    right = s - margin
    usable = right - margin

    line_h = int(s * 0.098)
    gap = int(s * 0.068)
    block_h = line_h * 4 + gap * 3
    top = (s - block_h) // 2

    radius = int(line_h * 0.07)

    # Ruling, in the Rhodia violet. Vanishes at home-screen size; rewards a closer look.
    rule_w = max(1, int(s * 0.004))
    for i in range(5):
        y = top - gap // 2 + i * (line_h + gap)
        d.line([(margin, y), (right, y)], fill=RULE, width=rule_w)

    # Three lines of writing and one struck out. Ragged right edges so they read as
    # written entries rather than a bar chart.
    lines = [
        (1.00, "ink"),
        (0.66, "ink"),
        (1.00, "void"),     # the quarter hour you lost
        (0.44, "ink"),
    ]

    for i, (width_fraction, kind) in enumerate(lines):
        y0 = top + i * (line_h + gap)
        y1 = y0 + line_h
        x1 = margin + usable * width_fraction

        if kind == "ink":
            d.rounded_rectangle([margin, y0, x1, y1], radius=radius, fill=INK)
        else:
            d.rounded_rectangle([margin, y0, x1, y1], radius=radius, fill=VIOLET)
            # Hatching, clipped to the bar, so it reads as struck out rather than coloured.
            layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
            hatched(ImageDraw.Draw(layer), (margin, y0, x1, y1),
                    (247, 241, 222, 120), int(s * 0.026), max(1, int(s * 0.007)))
            mask = Image.new("L", (s, s), 0)
            ImageDraw.Draw(mask).rounded_rectangle([margin, y0, x1, y1], radius=radius, fill=255)
            clipped = Image.new("RGBA", (s, s), (0, 0, 0, 0))
            clipped.paste(layer, (0, 0), mask)
            img = Image.alpha_composite(img.convert("RGBA"), clipped).convert("RGB")
            d = ImageDraw.Draw(img)

    return img.resize((size, size), Image.LANCZOS)

if __name__ == "__main__":
    import os
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(root, "WUUT", "Assets.xcassets", "AppIcon.appiconset", "icon-1024.png")
    icon = render()
    icon.save(out)                       # RGB, no alpha — iOS rejects icons with one
    print("wrote", out, icon.size, icon.mode)

    # Legibility check at the sizes it will actually be seen.
    sizes = [1024, 180, 120, 87, 60]
    pad, gap = 60, 40
    W = pad * 2 + 420 + gap + max(sizes[1:]) + 80
    H = pad * 2 + 420
    sheet = Image.new("RGB", (W, H), (237, 234, 227))
    sheet.paste(icon.resize((420, 420), Image.LANCZOS), (pad, pad))
    x = pad + 420 + gap
    y = pad
    for sz in sizes[1:]:
        small = icon.resize((sz, sz), Image.LANCZOS)
        sheet.paste(small, (x, y))
        y += sz + 18
    preview = os.path.join(root, "icon_preview.png")
    sheet.save(preview)
    print("wrote", preview, "(preview only, gitignored)")
