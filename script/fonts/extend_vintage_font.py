#!/usr/bin/env python3
"""Add the lowercase Portuguese diacritics Vintage ships without.

Run this once against a fresh dafont download, in place:

    pip install fonttools  # or: sudo pacman -S python-fonttools
    python3 script/fonts/extend_vintage_font.py app/assets/fonts/vintage/Vintage-Regular.ttf

The font (134 glyphs) already has 'tilde', 'acute' and a cedilla shape
(fused into the uppercase Ccedilla contour) it just never composed onto
lowercase letters. It has no grave or circumflex mark at all, upper or
lowercase, so those two are drawn from scratch here (grave as a mirror of
the existing acute; circumflex as a plain two-legged chevron) rather than
extracted from anything. Safe to re-run: skips any glyph that already
exists, so re-running after a font update won't duplicate work.
"""
import copy
import sys

from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

NEW_MARKS = ["grave", "circumflex"]
NEW_LETTERS = [
    ("atilde", "a", "tilde"),
    ("otilde", "o", "tilde"),
    ("ccedilla", "c", "cedilla"),
    ("agrave", "a", "grave"),
    ("acircumflex", "a", "circumflex"),
    ("ecircumflex", "e", "circumflex"),
    ("ocircumflex", "o", "circumflex"),
]
CMAP_ADDITIONS = {
    0x00E3: "atilde",
    0x00F5: "otilde",
    0x00E7: "ccedilla",
    0x00E0: "agrave",
    0x00E2: "acircumflex",
    0x00EA: "ecircumflex",
    0x00F4: "ocircumflex",
}


def bbox(glyf, name):
    g = glyf[name]
    return g.xMin, g.yMin, g.xMax, g.yMax


def center_x(b):
    return (b[0] + b[2]) / 2


def build_grave(f):
    """Mirror 'acute' horizontally about its own bounding-box center."""
    glyf = f["glyf"]
    gs = f.getGlyphSet()
    xmin, _, xmax, _ = bbox(glyf, "acute")
    mirror_c = xmin + xmax
    src = RecordingPen()
    gs["acute"].draw(src)
    pen = TTGlyphPen(glyf)
    for op, args in src.value:
        if op == "moveTo":
            (x, y), = args
            pen.moveTo((mirror_c - x, y))
        elif op == "lineTo":
            (x, y), = args
            pen.lineTo((mirror_c - x, y))
        elif op == "closePath":
            pen.closePath()
        else:
            raise ValueError(f"'acute' has an unexpected '{op}' segment — "
                              "extend this mirroring branch to handle it")
    glyph = pen.glyph()
    glyph.recalcBounds(glyf)
    return glyph, f["hmtx"]["acute"]


def build_circumflex(f):
    """A plain two-legged chevron (^) with a notch — no source to draw from."""
    glyf = f["glyf"]
    half_width, leg_width = 150, 70
    base_y, peak_y, notch_y = 535, 700, 620
    pen = TTGlyphPen(glyf)
    pen.moveTo((-half_width, base_y))
    pen.lineTo((0, peak_y))
    pen.lineTo((half_width, base_y))
    pen.lineTo((half_width - leg_width, base_y))
    pen.lineTo((0, notch_y))
    pen.lineTo((-half_width + leg_width, base_y))
    pen.closePath()
    glyph = pen.glyph()
    glyph.recalcBounds(glyf)
    return glyph, (500, -half_width)


def build_cedilla(f):
    """Extract the cedilla tail from Ccedilla: the one contour it has that
    plain 'C' doesn't. The standalone 'cedilla' glyph ships in the font but
    empty (reserved name, no outline) — this fills it in for real."""
    glyf = f["glyf"]
    gs = f.getGlyphSet()

    def contours_of(name):
        rp = RecordingPen()
        gs[name].draw(rp)
        contours, cur = [], []
        for op, args in rp.value:
            if op == "moveTo":
                cur = [(op, args)]
            elif op == "closePath":
                cur.append((op, args))
                contours.append(cur)
            else:
                cur.append((op, args))
        return contours

    def contour_bbox(c):
        pts = [a for _, args in c for a in args]
        xs, ys = [p[0] for p in pts], [p[1] for p in pts]
        return min(xs), min(ys), max(xs), max(ys)

    c_bbox = contour_bbox(contours_of("C")[0])
    tail = next(c for c in contours_of("Ccedilla") if contour_bbox(c) != c_bbox)

    pen = TTGlyphPen(glyf)
    for op, args in tail:
        getattr(pen, op)(*args) if op != "closePath" else pen.closePath()
    glyph = pen.glyph()
    glyph.recalcBounds(glyf)
    return glyph, f["hmtx"]["cedilla"]


def make_composite(glyf, base_name, mark_name, offset_x):
    """Clone 'ntilde' (base+tilde, an existing composite) as a structural
    template and repoint its two components — keeps the exact component flag
    layout the font already uses instead of guessing at it."""
    g = copy.deepcopy(glyf["ntilde"])
    g.components[0].glyphName, g.components[0].x, g.components[0].y = base_name, 0, 0
    g.components[1].glyphName, g.components[1].x, g.components[1].y = mark_name, offset_x, 0
    return g


def main(path):
    f = TTFont(path)
    glyf, hmtx = f["glyf"], f["hmtx"]
    order = f.getGlyphOrder()

    if "grave" not in order:
        glyf["grave"], hmtx["grave"] = build_grave(f)
    if "circumflex" not in order:
        glyf["circumflex"], hmtx["circumflex"] = build_circumflex(f)
    if glyf["cedilla"].numberOfContours == 0:  # reserved name, no outline yet
        glyf["cedilla"], hmtx["cedilla"] = build_cedilla(f)

    added = []
    for name, base, mark in NEW_LETTERS:
        if name in order:
            continue
        offset = round(center_x(bbox(glyf, base)) - center_x(bbox(glyf, mark)))
        glyf[name] = make_composite(glyf, base, mark, offset)
        hmtx[name] = hmtx[base]
        added.append(name)

    order = f.getGlyphOrder()
    for name in [*NEW_MARKS, *(n for n, _, _ in NEW_LETTERS)]:
        if name not in order:
            order.append(name)
    f.setGlyphOrder(order)
    glyf.glyphOrder = order

    for table in f["cmap"].tables:
        if table.isUnicode():
            table.cmap.update(CMAP_ADDITIONS)

    f.save(path)
    print(f"Added: {', '.join(added) or '(nothing new — already extended)'}")
    print(f"Total glyphs: {len(f.getGlyphOrder())}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(f"usage: {sys.argv[0]} path/to/Vintage-Regular.ttf")
    main(sys.argv[1])
