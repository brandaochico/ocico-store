# frozen_string_literal: true

require "spree/core/product_filters"

module TaxonFiltersHelper
  # The search sidebar, in order: the three navigation dimensions first (see
  # app/overrides/taxonomy_product_filters.rb), then the two that cut across
  # them. Solidus's own brand_filter is left out — it reads a "brand" property
  # this catalog doesn't use, so it always rendered an empty group.
  SIDEBAR_FILTERS = %i[
    origin_filter
    product_type_filter
    collection_filter
    condition_filter
    price_filter
  ].freeze

  # sealed_only: the all-products page while browsing, which lists no singles
  # (ProductsController#index) — so no "Cartas Avulsas" type to pick and no
  # condition filter, which only singles have.
  def applicable_filters_for(_taxon, sealed_only: false)
    filter_names = sealed_only ? SIDEBAR_FILTERS - %i[condition_filter] : SIDEBAR_FILTERS

    filter_names.filter_map do |filter_name|
      next unless Spree::Core::ProductFilters.respond_to?(filter_name)

      filter = Spree::Core::ProductFilters.send(filter_name)
      filter = without_singles(filter) if sealed_only && filter_name == :product_type_filter
      # A taxonomy that hasn't been seeded yields no options; rendering the
      # heading with an empty list would just be noise.
      filter if filter[:labels].present?
    end
  end

  private

  def without_singles(filter)
    singles = MainNavigationHelper::SINGLES_TAXON_NAME
    filter.merge(
      conds: filter[:conds].except(singles),
      labels: filter[:labels].reject { |_label, value| value == singles }
    )
  end
end
