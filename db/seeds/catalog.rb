# frozen_string_literal: true

# Idempotent — safe to run more than once (bin/rails db:seed re-runs everything).
#
# Seeds ocico store's catalog structure and an illustrative set of products.
#
# Three taxonomies drive both the header navigation and the search sidebar, and
# they are deliberately separate concerns:
#
#   Origem     where the product was printed, which in the TCG also decides its
#              language — one dimension, not two. Each taxon carries the ISO
#              country code that `spree_products.country_of_origin` is derived
#              from, so Fase 3's import duty keeps its source of truth.
#   Tipo       what kind of product it is (sealed formats plus loose singles).
#   Coleções   the set it belongs to, ordered by real release date.
#
# The ten most recent collections are the ones actually stocked. Three older
# ones (Paldea Evolved, Obsidian Flames, 151) are kept because the sample
# products below are real cards from them — inventing cards for the stocked
# sets would mean fabricating card numbers. Both go when a real catalog import
# lands. See "Fase 1" in the architecture plan for the modeling rationale.
module OcicoStore
  module CatalogSeed
    module_function

    def call
      update_store!
      option_types = seed_option_types
      seed_properties
      origins = seed_origin_taxonomy
      types = seed_type_taxonomy
      collections = seed_collections_taxonomy
      seed_products(option_types:, origins:, types:, collections:)
      retire_language_option_type
    end

    def update_store!
      store = Spree::Store.default
      return unless store

      store.update!(
        name: "ocico store",
        default_currency: "BRL",
        mail_from_address: "contato@ocicostore.com.br"
      )
    end

    def seed_option_types
      condition = find_or_create_option_type("condition", "Condição", [
        [ "nm", "NM — Near Mint" ],
        [ "lp", "LP — Levemente Jogada" ],
        [ "mp", "MP — Moderadamente Jogada" ],
        [ "hp", "HP — Muito Jogada" ],
        [ "dmg", "DMG — Danificada" ]
      ])

      # Modeled now, not used on any sample product yet — ready for when
      # graded card inventory becomes a real SKU line (see Fase 6+).
      find_or_create_option_type("grading", "Grading", [
        [ "raw", "Sem grading" ],
        [ "psa10", "PSA 10" ],
        [ "psa9", "PSA 9" ],
        [ "psa8", "PSA 8" ],
        [ "bgs95", "BGS 9.5" ]
      ])

      { condition: }
    end

    def find_or_create_option_type(name, presentation, value_pairs)
      option_type = Spree::OptionType.find_or_create_by!(name:) do |ot|
        ot.presentation = presentation
      end

      value_pairs.each_with_index do |(value_name, value_presentation), index|
        Spree::OptionValue.find_or_create_by!(option_type:, name: value_name) do |ov|
          ov.presentation = value_presentation
          ov.position = index + 1
        end
      end

      option_type
    end

    def seed_properties
      Spree::Property.find_or_create_by!(name: "rarity") { |p| p.presentation = "Raridade" }
      Spree::Property.find_or_create_by!(name: "card_number") { |p| p.presentation = "Número da Carta" }
    end

    # Where the product was printed. The flag goes after the name because that's
    # how the header shows it; the ISO code is what country_of_origin stores.
    def origins
      [
        [ "Brasil", "🇧🇷", "BR" ],
        [ "China", "🇨🇳", "CN" ],
        [ "Japão", "🇯🇵", "JP" ],
        [ "Coreia do Sul", "🇰🇷", "KR" ],
        [ "EUA", "🇺🇸", "US" ],
        [ "Indonésia", "🇮🇩", "ID" ]
      ]
    end

    # "Cartas Avulsas" is listed here with the sealed formats because it is a
    # kind of product, but the header gives it its own entry rather than burying
    # it in the "Produtos" dropdown.
    def product_types
      [
        "Booster Box",
        "Mini Booster Box",
        "ETB",
        "Booster Unitário",
        "Blister",
        "Caixas Colecionáveis",
        "Cartas Avulsas"
      ]
    end

    # Release dates are real and were looked up per set; they are what "the
    # seven most recent" in the header resolves against, so a wrong one here
    # silently reorders the menu.
    def collections
      [
        [ "Gem Pack Vol. 6", "CBB6C", "2026-08-07" ],
        [ "Storm Emeralda", "M6", "2026-07-31" ],
        [ "Pitch Black", "PBL", "2026-07-17" ],
        [ "Terastal Gathering", "CSV9.5C", "2026-06-12" ],
        [ "Stellar Crystal", "CSV9C", "2026-05-15" ],
        [ "Perfect Order", "POR", "2026-03-27" ],
        [ "Ascended Heroes", "ASC", "2026-01-30" ],
        [ "Phantasmal Flames", "PFL", "2025-11-14" ],
        [ "Mega Symphonia", "M1S", "2025-08-01" ],
        [ "Destined Rivals", "DRI", "2025-05-30" ],
        # Not stocked — kept only because the sample products are real cards
        # from these sets. They go with the demo catalog.
        [ "151", "MEW", "2023-09-22" ],
        [ "Obsidian Flames", "OBF", "2023-08-11" ],
        [ "Paldea Evolved", "PAL", "2023-06-09" ]
      ]
    end

    def seed_origin_taxonomy
      taxonomy = Spree::Taxonomy.find_or_create_by!(name: "Origem")

      # Taxons have no position column — ordering is the nested set's lft, which
      # follows creation order, so the array above is the header's order.
      origins.to_h do |name, flag, iso|
        [ iso, Spree::Taxon.find_or_create_by!(taxonomy:, parent: taxonomy.root, name: "#{name} #{flag}") ]
      end
    end

    def seed_type_taxonomy
      taxonomy = Spree::Taxonomy.find_or_create_by!(name: "Tipo")

      product_types.to_h do |name|
        [ name, Spree::Taxon.find_or_create_by!(taxonomy:, parent: taxonomy.root, name:) ]
      end
    end

    def seed_collections_taxonomy
      # Renames the old "Set" taxonomy in place so existing taxon/product links
      # survive rather than being orphaned by a fresh taxonomy.
      taxonomy = Spree::Taxonomy.find_by(name: "Set") || Spree::Taxonomy.find_or_create_by!(name: "Coleções")
      taxonomy.update!(name: "Coleções") unless taxonomy.name == "Coleções"

      collections.to_h do |name, code, released_on|
        taxon = Spree::Taxon.find_or_create_by!(taxonomy:, parent: taxonomy.root, name:)
        taxon.update!(description: code, released_on: Date.parse(released_on))
        [ name, taxon ]
      end
    end

    def seed_products(option_types:, origins:, types:, collections:)
      tax_category = Spree::TaxCategory.find_by(is_default: true) || Spree::TaxCategory.first
      shipping_category = Spree::ShippingCategory.find_by(name: "Default") || Spree::ShippingCategory.first

      condition = option_types[:condition]
      nm = condition.option_values.find_by!(name: "nm")
      lp = condition.option_values.find_by!(name: "lp")
      mp = condition.option_values.find_by!(name: "mp")

      singles_taxon = types.fetch("Cartas Avulsas")
      booster_box_taxon = types.fetch("Booster Box")

      singles = [
        {
          name: "Charizard ex (Illustration Rare)", sku_prefix: "OBF-125", price: 899.90,
          collection: "Obsidian Flames", origin: "US", rarity: "Illustration Rare",
          card_number: "125/197", option_types: [ condition ], variants: [ [ nm ], [ lp ], [ mp ] ]
        },
        {
          name: "Arcanine ex (Double Rare)", sku_prefix: "OBF-084", price: 129.90,
          collection: "Obsidian Flames", origin: "US", rarity: "Double Rare",
          card_number: "084/197", option_types: [ condition ], variants: [ [ nm ], [ lp ] ]
        },
        {
          name: "Mew ex (Special Art Rare)", sku_prefix: "MEW-205", price: 1299.90,
          collection: "151", origin: "JP", rarity: "Special Art Rare",
          card_number: "205/165", option_types: [ condition ], variants: [ [ nm ], [ lp ] ]
        },
        {
          name: "Pikachu (Rare)", sku_prefix: "MEW-137", price: 79.90,
          collection: "151", origin: "JP", rarity: "Rare",
          card_number: "137/165", option_types: [ condition ], variants: [ [ nm ], [ lp ], [ mp ] ]
        },
        {
          name: "Iron Valiant ex (Ultra Rare)", sku_prefix: "PAL-089", price: 149.90,
          collection: "Paldea Evolved", origin: "US", rarity: "Ultra Rare",
          card_number: "089/193", option_types: [ condition ], variants: [ [ nm ], [ lp ] ]
        },
        {
          name: "Tinkaton ex (Double Rare)", sku_prefix: "PAL-136", price: 99.90,
          collection: "Paldea Evolved", origin: "US", rarity: "Double Rare",
          card_number: "136/193", option_types: [ condition ], variants: [ [ nm ], [ lp ] ]
        }
      ]

      sealed = [
        {
          name: "Obsidian Flames Booster Box", sku: "OBF-BOX", price: 1899.90,
          collection: "Obsidian Flames", origin: "US"
        },
        {
          name: "151 Booster Box (Japonês)", sku: "MEW-BOX-JP", price: 2199.90,
          collection: "151", origin: "JP"
        }
      ]

      singles.each do |attrs|
        create_single!(
          attrs, tax_category:, shipping_category:,
          taxons: [ collections.fetch(attrs[:collection]), origins.fetch(attrs[:origin]), singles_taxon ]
        )
      end

      sealed.each do |attrs|
        create_sealed!(
          attrs, tax_category:, shipping_category:,
          taxons: [ collections.fetch(attrs[:collection]), origins.fetch(attrs[:origin]), booster_box_taxon ]
        )
      end
    end

    # The `language` option type is superseded by the Origem taxonomy: in the
    # TCG the printing origin decides the language, so keeping both meant two
    # places to get the same fact wrong. Variants that used it are rebuilt above
    # as condition-only, which leaves stale language-suffixed SKUs behind — those
    # are removed here so the option type can go.
    def retire_language_option_type
      option_type = Spree::OptionType.find_by(name: "language")
      return unless option_type

      stale = Spree::Variant.joins(:option_values)
                            .where(spree_option_values: { option_type_id: option_type.id })
      stale.find_each { |variant| variant.destroy! }

      Spree::Product.joins(:option_types)
                    .where(spree_option_types: { id: option_type.id })
                    .find_each { |product| product.option_types.delete(option_type) }

      option_type.option_values.destroy_all
      option_type.destroy!
    end

    def create_single!(attrs, tax_category:, shipping_category:, taxons:)
      product = Spree::Product.find_or_create_by!(name: attrs[:name]) do |p|
        p.description = "Carta avulsa da coleção #{attrs[:collection]}. Dado de exemplo do catálogo — " \
          "substituir por importação real de estoque."
        p.price = attrs[:price]
        p.tax_category = tax_category
        p.shipping_category = shipping_category
        p.available_on = Time.current
        p.country_of_origin = attrs[:origin]
        p.option_types = attrs[:option_types]
      end

      taxons.each { |taxon| product.taxons << taxon unless product.taxons.include?(taxon) }
      product.set_property("rarity", attrs[:rarity])
      product.set_property("card_number", attrs[:card_number])

      attrs[:variants].each do |option_values|
        sku = "#{attrs[:sku_prefix]}-#{option_values.map(&:name).join('-').upcase}"
        next if Spree::Variant.exists?(sku:)

        variant = product.variants.create!(sku:, price: attrs[:price], option_values:)
        variant.stock_items.each { |item| item.set_count_on_hand(5) }
      end
    end

    def create_sealed!(attrs, tax_category:, shipping_category:, taxons:)
      product = Spree::Product.find_or_create_by!(name: attrs[:name]) do |p|
        p.description = "Produto selado. Dado de exemplo do catálogo — substituir por importação real de estoque."
        p.price = attrs[:price]
        p.sku = attrs[:sku]
        p.tax_category = tax_category
        p.shipping_category = shipping_category
        p.available_on = Time.current
        p.country_of_origin = attrs[:origin]
      end

      taxons.each { |taxon| product.taxons << taxon unless product.taxons.include?(taxon) }
      product.master.stock_items.each { |item| item.set_count_on_hand(10) }
    end
  end
end

OcicoStore::CatalogSeed.call
