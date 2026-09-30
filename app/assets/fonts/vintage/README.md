# Vintage

Heading display face for the ocico store brand (`--font-heading`).

Two things to know before touching this:

1. **Licensing.** dafont distributes this as free for personal use only. The
   store is commercial, so using it here is a deliberate decision by the owner,
   not an oversight. The file is deliberately **not committed** — this repo is
   public, and publishing the binary would be redistribution on top of the usage
   question. `.gitignore` keeps it out; place `Vintage-Regular.ttf` in this
   directory by hand on each machine that needs it.

2. **It didn't cover Portuguese out of the box, and still doesn't fully.** The
   font as downloaded maps 134 characters and is missing every lowercase
   accented Portuguese vowel plus `ç`. Uppercase `À Â Ã Ê Ô Õ` and the em dash
   are still missing — those weren't asked for and haven't come up in
   practice, so they're left as a known gap. Any heading using one of those
   still renders it in the next font in the stack, mid-word. See the
   `--font-heading` comment in `app/assets/stylesheets/application.tailwind.css`.

## Extended glyphs

The lowercase gap above is fixed: `script/fonts/extend_vintage_font.py` hand-adds
`à â ã ç ê ô õ` directly into the local `.ttf`. Two of those (grave, circumflex)
are drawn from scratch — the font has no accent mark to build them from, upper
or lowercase — the other five reuse marks the font already had (`tilde`,
`acute`) or a shape hiding in an existing uppercase glyph (the cedilla tail
lives fused into `Ccedilla`'s outline; the standalone `cedilla` glyph name
exists in the font but ships empty).

**This means the file in this directory is not a stock dafont download** —
it's that download plus these hand-added glyphs. Since it's git-ignored (see
above), that extra work doesn't travel with the repo. On a fresh machine:

```
# after placing the stock Vintage-Regular.ttf here per the instructions above
pip install fonttools   # or: sudo pacman -S python-fonttools
python3 script/fonts/extend_vintage_font.py app/assets/fonts/vintage/Vintage-Regular.ttf
```

Safe to re-run — it skips any glyph that's already there. If the store ever
needs a character this doesn't cover, extend that script rather than hand-editing
the binary again; it's the record of how every glyph here was built.
