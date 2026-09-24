class AddCountryOfOriginToSpreeProducts < ActiveRecord::Migration[8.1]
  def change
    # ISO 3166-1 alpha-2 (e.g. "JP", "US"). Product-level, not variant-level —
    # a whole set/print run shares one country of origin. Feeds the future
    # import duty calculator (Fase 3).
    add_column :spree_products, :country_of_origin, :string
  end
end
