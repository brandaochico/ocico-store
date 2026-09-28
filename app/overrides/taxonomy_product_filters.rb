# frozen_string_literal: true

# The search sidebar's three dimensions — country of origin, product type and
# collection — as combinable checkbox filters.
#
# These are taxon-backed, unlike condition (option values) and price (amounts),
# so they need their own search scopes. Same additive pattern as
# app/overrides/condition_product_filter.rb: flat file, wrapping module matching
# the filename for Zeitwerk, and `module ::Spree::Core::ProductFilters` with a
# leading `::` so the real namespace is reopened rather than nested under this
# one. Registered in app/helpers/taxon_filters_helper.rb.
#
# The header shows only the seven most recent collections; the sidebar lists
# them all, because a filter that hides options silently returns incomplete
# results.
module TaxonomyProductFilters
  require "spree/core/product_filters"

  %i[origin product_type collection].each do |dimension|
    Spree::Product.add_search_scope :"#{dimension}_any" do |*opts|
      scope = opts.filter_map { |value|
        Spree::Core::ProductFilters.public_send(:"#{dimension}_filter")[:conds][value]
      }.inject { |scope1, scope2| scope1.or(scope2) }

      # A subquery, not a join: chaining two of these scopes onto a single
      # joins(:taxons) asks one joined row to match two different taxons at
      # once, so "Japão + Booster Box" silently returned nothing. Matching on
      # id keeps each dimension independent and combinable.
      Spree::Product.where(id: Spree::Product.joins(:taxons).where(scope).select(:id))
    end
  end

  module ::Spree::Core::ProductFilters
    # @param taxonomy_name [String] the taxonomy to read the options from
    # @param label [String] the heading shown above the checkboxes
    # @param scope [Symbol] the search scope that decodes the selected labels
    # @param order the column to list the options by
    def self.taxonomy_filter(taxonomy_name, label:, scope:, order: :lft)
      taxonomy = Spree::Taxonomy.find_by(name: taxonomy_name)
      taxons = taxonomy ? taxonomy.taxons.where.not(parent_id: nil).order(order).to_a : []
      taxon_table = Spree::Taxon.arel_table
      conds = taxons.map { |taxon| [ taxon.name, taxon_table[:id].eq(taxon.id) ] }

      {
        name: label,
        scope: scope,
        conds: Hash[*conds.flatten],
        # Already ordered above, so the labels keep that order rather than
        # being re-sorted alphabetically the way Solidus's own brand filter is.
        labels: conds.map { |key, _condition| [ key, key ] }
      }
    end

    def self.origin_filter
      taxonomy_filter("Origem", label: I18n.t("storefront.navigation.countries"), scope: :origin_any)
    end

    def self.product_type_filter
      taxonomy_filter("Tipo", label: I18n.t("storefront.navigation.products"), scope: :product_type_any)
    end

    def self.collection_filter
      taxonomy_filter(
        "Coleções",
        label: I18n.t("storefront.navigation.collections"),
        scope: :collection_any,
        order: Arel.sql("released_on DESC NULLS LAST")
      )
    end
  end
end
