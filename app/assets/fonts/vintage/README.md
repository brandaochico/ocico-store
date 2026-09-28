# Vintage

Heading display face for the ocico store brand (`--font-heading`).

Two things to know before touching this:

1. **Licensing.** dafont distributes this as free for personal use only. The
   store is commercial, so using it here is a deliberate decision by the owner,
   not an oversight. The file is deliberately **not committed** — this repo is
   public, and publishing the binary would be redistribution on top of the usage
   question. `.gitignore` keeps it out; place `Vintage-Regular.ttf` in this
   directory by hand on each machine that needs it.

2. **It does not cover Portuguese.** The font maps 134 characters and is missing
   `à â ã ç ê ô õ` (lowercase) and `À Â Ã Ê Ô Õ` plus the em dash. It has no
   tilde or circumflex mark at all, so the glyphs can't be composed from what's
   there. Any heading with those characters renders them in the next font in the
   stack, mid-word. See the `--font-heading` comment in
   `app/assets/stylesheets/application.tailwind.css`.
