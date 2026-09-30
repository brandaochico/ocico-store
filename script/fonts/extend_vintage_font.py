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
extracted from anything.

Every new letter is built as a SIMPLE glyph (base contours + mark contours
merged into one glyph), not a composite referencing components. Two
reasons: (1) it's what this font's own Ccedilla already does, rather than
a pattern invented here, and (2) a first version built as composites (the
same structural pattern the font's own aacute/eacute/ntilde use) rendered
a visible dark blob in place of the tilde on some real-world combinations
at small sizes — root cause not fully pinned down (thin-mark hinting
collapse under absent instructions is the leading theory), so this favors
the more universally-supported simple-glyph path plus the OVERLAP_SIMPLE
flag rather than relying on composite/component-transform correctness.
Marks also sit with more vertical clearance above the base letter than a
literal copy of the font's own aacute/ntilde offsets would give, as a
safety margin against exactly that kind of collapse.

Safe to re-run: skips any glyph that already exists, so re-running after
a font update won't duplicate work.
"""
import sys

from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont
from fontTools.ttLib.tables._g_l_y_f import flagOverlapSimple

# Extra vertical clearance (in font units, 1000/em) added on top of a
# center-to-center offset, so thin marks don't sit close enough to the
# base letter to risk merging into it once hinting/rounding gets involved.
CLEARANCE_Y = 40

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


def replay_translated(pen, glyphset, name, dx=0, dy=0):
    """Redraw `name`'s contours into `pen`, offset by (dx, dy)."""
    src = RecordingPen()
    glyphset[name].draw(src)
    for op, args in src.value:
        if op == "closePath":
            pen.closePath()
        else:
            pen_method = getattr(pen, op)
            pen_method(*[(x + dx, y + dy) for x, y in args])


def build_grave(f):
    """Mirror 'acute' horizontally about its own bbox center. A plain
    coordinate mirror flips the contour's winding direction along with its
    shape, so the point order is also reversed here to keep it matching the
    font's own CW-outer convention (every other outer contour in this font,
    including 'acute' and the hand-drawn 'circumflex' below, winds CW —
    an early version of this script skipped the reversal and left grave the
    only CCW outer contour in the font)."""
    glyf = f["glyf"]
    gs = f.getGlyphSet()
    xmin, _, xmax, _ = bbox(glyf, "acute")
    mirror_c = xmin + xmax
    src = RecordingPen()
    gs["acute"].draw(src)
    segments = [seg for seg in src.value if seg[0] != "closePath"]
    mirrored = [(op, ((mirror_c - args[0][0], args[0][1]),)) for op, args in segments]
    pen = TTGlyphPen(glyf)
    first_op, first_args = mirrored[-1]
    pen.moveTo(first_args[0])
    for op, args in reversed(mirrored[:-1]):
        pen.lineTo(args[0])
    pen.closePath()
    glyph = pen.glyph()
    glyph.recalcBounds(glyf)
    return glyph, f["hmtx"]["acute"]


def build_circumflex(f):
    """A plain two-legged chevron (^) with a notch — no source to draw from."""
    glyf = f["glyf"]
    half_width, leg_width = 150, 70
    base_y = 535 + CLEARANCE_Y
    peak_y = base_y + 165
    notch_y = base_y + 85
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
    empty (reserved name, no outline) — this fills it in for real. No
    clearance concerns here: cedilla hangs below the baseline, not close to
    anything above it."""
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
        if op == "closePath":
            pen.closePath()
        else:
            getattr(pen, op)(*args)
    glyph = pen.glyph()
    glyph.recalcBounds(glyf)
    return glyph, f["hmtx"]["cedilla"]


def build_letter(f, base_name, mark_name):
    """Merge base + mark into one simple glyph (contours concatenated, mark
    translated into place) rather than a composite — see module docstring."""
    glyf = f["glyf"]
    gs = f.getGlyphSet()
    base_bbox = bbox(glyf, base_name)
    mark_bbox = bbox(glyf, mark_name)
    offset_x = round(center_x(base_bbox) - center_x(mark_bbox))

    pen = TTGlyphPen(glyf)
    replay_translated(pen, gs, base_name)
    replay_translated(pen, gs, mark_name, dx=offset_x)
    glyph = pen.glyph()
    glyph.recalcBounds(glyf)
    glyph.flags[0] |= flagOverlapSimple
    return glyph


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
        glyf[name] = build_letter(f, base, mark)
        hmtx[name] = hmtx[base]
        added.append(name)

    order = f.getGlyphOrder()
    for name in ["grave", "circumflex", *(n for n, _, _ in NEW_LETTERS)]:
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
