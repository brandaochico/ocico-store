# Collection sprites

Per-collection Pokémon/character art shown on `/colecoes` (`collections#index`,
via `CollectionSpritesHelper`). **This directory's contents are not
committed** — same reasoning as `app/assets/fonts/vintage`: these are Pokémon
franchise (Nintendo/Creatures/Game Freak) sprites, official or fan-made, with
no redistribution licence, and this repo is public. Each machine needs these
files placed here by hand.

Processing: every file here has already had a 1px white outline baked in via
`script/collections/add_sprite_outline.py` (run against the raw source), and
is displayed by `CollectionSpritesHelper` at its original resolution scaled up
with `image-rendering: pixelated` — never re-touch a file in place; regenerate
it from its source with that script instead.

## Sources, one per file

Filenames match the collection taxon's slug (`CollectionSpritesHelper::SPRITES`).
"GSC pack" is the owner's local Gen 1-8 Gold/Silver/Crystal-style sprite
collection (Downloads folder, not itself in this repo) — filenames below are
that pack's own numbering.

| File | Source | Credit shown on-page |
|---|---|---|
| `gem-pack-vol-6.png` | GSC pack `840.png` (Applin) | Pokémon GSC Essencials |
| `storm-emeralda.png` | [PokéAPI/sprites, gen-v black-white `10079.png`](https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions/generation-v/black-white/10079.png) | PokéAPI |
| `pitch-black.png` | [kiriaura — Mega Darkrai Sprite](https://www.deviantart.com/kiriaura/art/Mega-Darkrai-Sprite-1274165733) | kiriaura |
| `terastal-gathering.png` | GSC pack `700.png` (Sylveon) | Pokémon GSC Essencials |
| `stellar-crystal.png` | GSC pack `025s.png` (Pikachu, shiny) | Pokémon GSC Essencials |
| `perfect-order.png` | [kiriaura — Mega Zygarde Sprite](https://www.deviantart.com/kiriaura/art/Mega-Zygarde-Sprite-1255400241) | kiriaura |
| `ascended-heroes.png` | [kiriaura — Mega Dragonite Sprite](https://www.deviantart.com/kiriaura/art/Mega-Dragonite-Sprite-1221861010) | kiriaura |
| `phantasmal-flames.png` | GSC pack `006m.png` — that file is itself [Eli-eli76 — Mega Charizard X (GSC Style)](https://www.deviantart.com/eli-eli76/art/Mega-Charizard-X-(GSC-Style)-790800391) | Eli-eli76 |
| `mega-symphonia.png` | GSC pack `282m.png` — that file is itself [PomPomKing — "Let me in, I'm a fairy"](https://www.deviantart.com/pompomking/art/Let-me-in%2C-I'm-a-fairy-786260058) | PomPomKing |
| `destined-rivals.png` | GSC pack `150.png` (Mewtwo) | Pokémon GSC Essencials |
| `151.png` | GSC pack `151.png` (Mew) | Pokémon GSC Essencials |
| `obsidian-flames.png` | GSC pack `006s.png` (Charizard, shiny) | Pokémon GSC Essencials |
| `paldea-evolved.png` | GSC pack `126.png` (Magmar) | Pokémon GSC Essencials |

To restore on a fresh machine: copy each GSC-pack file from the owner's pack
(or re-fetch each linked URL) and re-run, e.g.:

```
python3 script/collections/add_sprite_outline.py ~/Downloads/<pack>/151.png app/assets/images/collections/151.png
```
