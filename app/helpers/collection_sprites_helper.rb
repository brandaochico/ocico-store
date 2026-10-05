# frozen_string_literal: true

# Per-collection sprite art shown on /colecoes (collections#index) — see
# app/assets/images/collections/README.md for what each file is, where it
# came from, and why the directory itself is git-ignored.
#
# Keyed by the collection taxon's own slug (the last permalink segment,
# e.g. "set/obsidian-flames" -> "obsidian-flames") rather than an id, so this
# stays readable and doesn't break if a taxon gets recreated with a new id.
module CollectionSpritesHelper
  GSC_ESSENTIALS = "Pokémon GSC Essencials"

  SPRITES = {
    "gem-pack-vol-6" => { file: "gem-pack-vol-6.png", credit_name: GSC_ESSENTIALS, credit_url: nil },
    "storm-emeralda" => { file: "storm-emeralda.png", credit_name: "PokéAPI",
                           credit_url: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions/generation-v/black-white/10079.png" },
    "pitch-black" => { file: "pitch-black.png", credit_name: "kiriaura",
                        credit_url: "https://www.deviantart.com/kiriaura/art/Mega-Darkrai-Sprite-1274165733" },
    "terastal-gathering" => { file: "terastal-gathering.png", credit_name: GSC_ESSENTIALS, credit_url: nil },
    "stellar-crystal" => { file: "stellar-crystal.png", credit_name: GSC_ESSENTIALS, credit_url: nil },
    "perfect-order" => { file: "perfect-order.png", credit_name: "kiriaura",
                          credit_url: "https://www.deviantart.com/kiriaura/art/Mega-Zygarde-Sprite-1255400241" },
    "ascended-heroes" => { file: "ascended-heroes.png", credit_name: "kiriaura",
                            credit_url: "https://www.deviantart.com/kiriaura/art/Mega-Dragonite-Sprite-1221861010" },
    "phantasmal-flames" => { file: "phantasmal-flames.png", credit_name: "Eli-eli76",
                              credit_url: "https://www.deviantart.com/eli-eli76/art/Mega-Charizard-X-(GSC-Style)-790800391" },
    "mega-symphonia" => { file: "mega-symphonia.png", credit_name: "ocico", credit_url: nil },
    "destined-rivals" => { file: "destined-rivals.png", credit_name: GSC_ESSENTIALS, credit_url: nil },
    "151" => { file: "151.png", credit_name: GSC_ESSENTIALS, credit_url: nil },
    "obsidian-flames" => { file: "obsidian-flames.png", credit_name: GSC_ESSENTIALS, credit_url: nil },
    "paldea-evolved" => { file: "paldea-evolved.png", credit_name: GSC_ESSENTIALS, credit_url: nil }
  }.freeze

  def collection_sprite_for(taxon)
    SPRITES[taxon.permalink.to_s.split("/").last]
  end
end
