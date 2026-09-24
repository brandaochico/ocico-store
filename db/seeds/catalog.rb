# frozen_string_literal: true

# Idempotent — safe to run more than once (bin/rails db:seed re-runs everything).
# Seeds Ocico Store's illustrative Pokémon TCG catalog: option types
# (condition/language/grading), properties (rarity/card number), the "Set"
# taxonomy, and a handful of sample products across real sets. This is
# demo/dev data meant to prove the data model out — replace with a real
# catalog import once the business has one. See "Fase 1" in the architecture
# plan for the modeling rationale.
module OcicoStore
  module CatalogSeed
    module_function

    def call
      update_store!
      option_types = seed_option_types
      seed_properties
      taxonomy = seed_set_taxonomy
      seed_products(option_types:, taxonomy:)
    end

    def update_store!
      store = Spree::Store.default
      return unless store

      store.update!(
        name: "Ocico Store",
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

      language = find_or_create_option_type("language", "Idioma", [
        [ "en", "Inglês" ],
        [ "jp", "Japonês" ],
        [ "pt-br", "Português (BR)" ]
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

      { condition:, language: }
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

    def seed_set_taxonomy
      taxonomy = Spree::Taxonomy.find_or_create_by!(name: "Set")
      root = taxonomy.root

      [ "Obsidian Flames", "151", "Paldea Evolved" ].each do |set_name|
        Spree::Taxon.find_or_create_by!(taxonomy:, parent: root, name: set_name)
      end

      taxonomy
    end

    def seed_products(option_types:, taxonomy:)
      tax_category = Spree::TaxCategory.find_by(is_default: true) || Spree::TaxCategory.first
      shipping_category = Spree::ShippingCategory.find_by(name: "Default") || Spree::ShippingCategory.first

      condition = option_types[:condition]
      language = option_types[:language]
      nm = condition.option_values.find_by!(name: "nm")
      lp = condition.option_values.find_by!(name: "lp")
      mp = condition.option_values.find_by!(name: "mp")
      en = language.option_values.find_by!(name: "en")
      jp = language.option_values.find_by!(name: "jp")

      obsidian_flames = taxonomy.taxons.find_by!(name: "Obsidian Flames")
      set_151 = taxonomy.taxons.find_by!(name: "151")
      paldea_evolved = taxonomy.taxons.find_by!(name: "Paldea Evolved")

      singles = [
        {
          name: "Charizard ex (Illustration Rare)", sku_prefix: "OBF-125", price: 899.90,
          taxon: obsidian_flames, country_of_origin: "US", rarity: "Illustration Rare",
          card_number: "125/197", option_types: [ condition ], variants: [ [ nm ], [ lp ], [ mp ] ]
        },
        {
          name: "Arcanine ex (Double Rare)", sku_prefix: "OBF-084", price: 129.90,
          taxon: obsidian_flames, country_of_origin: "US", rarity: "Double Rare",
          card_number: "084/197", option_types: [ condition ], variants: [ [ nm ], [ lp ] ]
        },
        {
          name: "Mew ex (Special Art Rare)", sku_prefix: "MEW-205", price: 1299.90,
          taxon: set_151, country_of_origin: "JP", rarity: "Special Art Rare",
          card_number: "205/165", option_types: [ condition, language ],
          variants: [ [ nm, en ], [ lp, en ], [ nm, jp ], [ lp, jp ] ]
        },
        {
          name: "Pikachu (Rare)", sku_prefix: "MEW-137", price: 79.90,
          taxon: set_151, country_of_origin: "JP", rarity: "Rare",
          card_number: "137/165", option_types: [ condition ], variants: [ [ nm ], [ lp ], [ mp ] ]
        },
        {
          name: "Iron Valiant ex (Ultra Rare)", sku_prefix: "PAL-089", price: 149.90,
          taxon: paldea_evolved, country_of_origin: "US", rarity: "Ultra Rare",
          card_number: "089/193", option_types: [ condition ], variants: [ [ nm ], [ lp ] ]
        },
        {
          name: "Tinkaton ex (Double Rare)", sku_prefix: "PAL-136", price: 99.90,
          taxon: paldea_evolved, country_of_origin: "US", rarity: "Double Rare",
          card_number: "136/193", option_types: [ condition ], variants: [ [ nm ], [ lp ] ]
        }
      ]

      sealed = [
        {
          name: "Obsidian Flames Booster Box", sku: "OBF-BOX", price: 1899.90,
          taxon: obsidian_flames, country_of_origin: "US"
        },
        {
          name: "151 Booster Box (Japonês)", sku: "MEW-BOX-JP", price: 2199.90,
          taxon: set_151, country_of_origin: "JP"
        }
      ]

      singles.each { |attrs| create_single!(attrs, tax_category:, shipping_category:) }
      sealed.each { |attrs| create_sealed!(attrs, tax_category:, shipping_category:) }
    end

    def create_single!(attrs, tax_category:, shipping_category:)
      product = Spree::Product.find_or_create_by!(name: attrs[:name]) do |p|
        p.description = "Carta avulsa do set #{attrs[:taxon].name}. Dado de exemplo do catálogo — " \
          "substituir por importação real de estoque."
        p.price = attrs[:price]
        p.tax_category = tax_category
        p.shipping_category = shipping_category
        p.available_on = Time.current
        p.country_of_origin = attrs[:country_of_origin]
        p.option_types = attrs[:option_types]
      end

      product.taxons << attrs[:taxon] unless product.taxons.include?(attrs[:taxon])
      product.set_property("rarity", attrs[:rarity])
      product.set_property("card_number", attrs[:card_number])

      attrs[:variants].each do |option_values|
        sku = "#{attrs[:sku_prefix]}-#{option_values.map(&:name).join('-').upcase}"
        next if Spree::Variant.exists?(sku:)

        variant = product.variants.create!(sku:, price: attrs[:price], option_values:)
        variant.stock_items.each { |item| item.set_count_on_hand(5) }
      end
    end

    def create_sealed!(attrs, tax_category:, shipping_category:)
      product = Spree::Product.find_or_create_by!(name: attrs[:name]) do |p|
        p.description = "Produto selado. Dado de exemplo do catálogo — substituir por importação real de estoque."
        p.price = attrs[:price]
        p.sku = attrs[:sku]
        p.tax_category = tax_category
        p.shipping_category = shipping_category
        p.available_on = Time.current
        p.country_of_origin = attrs[:country_of_origin]
      end

      product.taxons << attrs[:taxon] unless product.taxons.include?(attrs[:taxon])
      product.master.stock_items.each { |item| item.set_count_on_hand(10) }
    end
  end
end

OcicoStore::CatalogSeed.call
