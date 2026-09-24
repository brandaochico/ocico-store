# frozen_string_literal: true

# Additive: a new search scope + filter definition alongside Spree::Core::
# ProductFilters' own price_filter/brand_filter (lib/spree/core/product_filters.rb
# in solidus_core — that file explicitly invites this: "make a copy... and
# modify it", but reopening the module is simpler and avoids load-order
# issues with `require`). Flat file + wrapping module (not a spree/product_filters/
# subdirectory) to satisfy the Zeitwerk eager-load check in
# spec/solidus_starter_frontend_spec_helper.rb — this file's own top-level
# code isn't a class/module definition, so it needs a constant matching its
# path for Zeitwerk, same pattern as the other app/overrides/*.rb files.
# Registered in TaxonFiltersHelper#applicable_filters_for
# (app/helpers/taxon_filters_helper.rb — our own generated file, edited
# directly since it isn't vendor/gem code).
module ConditionProductFilter
  require "spree/core/product_filters"

  Spree::Product.add_search_scope :condition_any do |*opts|
    scope = opts.filter_map { |value|
      Spree::Core::ProductFilters.condition_filter[:conds][value]
    }.inject { |scope1, scope2| scope1.or(scope2) }

    Spree::Product.joins(variants: :option_values).where(scope).distinct
  end

  # `module ::Spree::Core::ProductFilters` (leading `::`, fully qualified) reopens
  # the REAL top-level namespace — without it, this would nest a brand new
  # ConditionProductFilter::Spree::Core::ProductFilters instead.
  module ::Spree::Core::ProductFilters
    def self.condition_filter
      option_value_table = Spree::OptionValue.arel_table
      condition_type = Spree::OptionType.find_by(name: "condition")
      values = condition_type ? condition_type.option_values.order(:position) : []
      conds = values.map { |option_value| [ option_value.presentation, option_value_table[:id].eq(option_value.id) ] }

      {
        name: "Condição",
        scope: :condition_any,
        conds: Hash[*conds.flatten],
        labels: conds.map { |key, _value| [ key, key ] }
      }
    end
  end
end
