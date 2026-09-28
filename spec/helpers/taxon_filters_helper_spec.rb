# frozen_string_literal: true

require 'solidus_starter_frontend_spec_helper'

RSpec.describe TaxonFiltersHelper, type: :helper do
  subject(:filters) { applicable_filters_for(nil) }

  describe "#applicable_filters_for" do
    # Each of the three navigation dimensions reads a taxonomy by name, so a
    # database without them yields no options at all.
    context "when no taxonomy has been seeded" do
      it "offers only the filters that have something to offer" do
        expect(filters.map { |filter| filter[:name] }).not_to include(
          I18n.t("storefront.navigation.countries"),
          I18n.t("storefront.navigation.products"),
          I18n.t("storefront.navigation.collections")
        )
      end
    end

    context "with the navigation taxonomies seeded" do
      before do
        {
          "Origem" => [ "Japão 🇯🇵", "EUA 🇺🇸" ],
          "Tipo" => [ "Booster Box", "Cartas Avulsas" ],
          "Coleções" => [ "Destined Rivals" ]
        }.each do |taxonomy_name, taxon_names|
          taxonomy = Spree::Taxonomy.create!(name: taxonomy_name)
          taxon_names.each { |name| Spree::Taxon.create!(taxonomy:, parent: taxonomy.root, name:) }
        end
      end

      it "offers country, product type and collection, in that order" do
        expect(filters.map { |filter| filter[:name] }.first(3)).to eq [
          I18n.t("storefront.navigation.countries"),
          I18n.t("storefront.navigation.products"),
          I18n.t("storefront.navigation.collections")
        ]
      end

      it "lists each taxonomy's own taxons as the options" do
        countries = filters.find { |filter| filter[:name] == I18n.t("storefront.navigation.countries") }

        expect(countries[:labels].map(&:first)).to contain_exactly("Japão 🇯🇵", "EUA 🇺🇸")
      end

      # Solidus's brand_filter reads a "brand" property this catalog has no use
      # for, so it was dropped rather than left rendering an empty group.
      it "does not offer the brand filter" do
        expect(filters.map { |filter| filter[:name] }).not_to include("Brands")
      end
    end
  end
end
