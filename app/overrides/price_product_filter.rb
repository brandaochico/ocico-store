# frozen_string_literal: true

# Solidus's default price_filter (lib/spree/core/product_filters.rb) hardcodes
# USD-appropriate brackets ($10/$15/$18/$20) — meaningless for a TCG catalog
# priced in BRL from ~R$80 to ~R$2200. Same reopen pattern (and flat-file/
# wrapping-module Zeitwerk requirement) as condition_product_filter.rb.
module PriceProductFilter
  require "spree/core/product_filters"

  module ::Spree::Core::ProductFilters
    def self.price_filter
      value = Spree::Price.arel_table
      conds = [
        [ "Até #{format_price(100)}", value[:amount].lteq(100) ],
        [ "#{format_price(100)} - #{format_price(300)}", value[:amount].between(100..300) ],
        [ "#{format_price(300)} - #{format_price(800)}", value[:amount].between(300..800) ],
        [ "#{format_price(800)} - #{format_price(1500)}", value[:amount].between(800..1500) ],
        [ "Acima de #{format_price(1500)}", value[:amount].gteq(1500) ]
      ]
      {
        name: "Faixa de Preço",
        scope: :price_range_any,
        conds: Hash[*conds.flatten],
        labels: conds.map { |key, _value| [ key, key ] }
      }
    end
  end
end
