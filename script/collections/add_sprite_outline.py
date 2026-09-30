#!/usr/bin/env python3
"""Add a thin white outline to a sprite's silhouette, preserving transparency
everywhere else.

    python3 script/collections/add_sprite_outline.py input.png output.png [thickness_px]

Works on the image's actual alpha channel (not a bounding box), so it follows
the sprite's real silhouette — including holes and disconnected parts. Dilates
the alpha mask by `thickness_px` (default 1) using 4-directional shifts, fills
that dilated area white, then composites the original sprite on top — so only
the ring between the original silhouette and the dilated one stays white.
"""
import sys

from PIL import Image, ImageChops


def dilate_alpha(alpha, thickness):
    """Grow the opaque region of an 'L' mode alpha mask by `thickness` px,
    one ring at a time, via 4-directional shift-and-max (a cheap stand-in for
    a proper morphological dilation — plenty for a 1-2px outline)."""
    result = alpha
    for _ in range(thickness):
        for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
            result = ImageChops.lighter(result, _shift(result, dx, dy))
    return result


def _shift(img, dx, dy):
    w, h = img.size
    shifted = Image.new("L", (w, h), 0)
    box = (max(dx, 0), max(dy, 0), w + min(dx, 0), h + min(dy, 0))
    src_box = (max(-dx, 0), max(-dy, 0), w + min(-dx, 0), h + min(-dy, 0))
    shifted.paste(img.crop(src_box), box)
    return shifted


def add_outline(src_path, dst_path, thickness=1):
    img = Image.open(src_path).convert("RGBA")
    alpha = img.split()[3]
    dilated = dilate_alpha(alpha, thickness)

    white_halo = Image.new("RGBA", img.size, (255, 255, 255, 255))
    white_halo.putalpha(dilated)

    out = Image.alpha_composite(white_halo, img)
    out.save(dst_path)


if __name__ == "__main__":
    if len(sys.argv) not in (3, 4):
        sys.exit(f"usage: {sys.argv[0]} input.png output.png [thickness_px]")
    thickness = int(sys.argv[3]) if len(sys.argv) == 4 else 1
    add_outline(sys.argv[1], sys.argv[2], thickness)
    print(f"wrote {sys.argv[2]} (outline {thickness}px)")
