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

  def applicable_filters_for(_taxon)
    SIDEBAR_FILTERS.filter_map do |filter_name|
      next unless Spree::Core::ProductFilters.respond_to?(filter_name)

      filter = Spree::Core::ProductFilters.send(filter_name)
      # A taxonomy that hasn't been seeded yields no options; rendering the
      # heading with an empty list would just be noise.
      filter if filter[:labels].present?
    end
  end
end
