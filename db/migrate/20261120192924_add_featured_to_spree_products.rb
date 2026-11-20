# frozen_string_literal: true

# "Destaque na home": the owner picks which products open the home page
# (HomeController). Solidus has no such flag.
class AddFeaturedToSpreeProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :spree_products, :featured, :boolean, default: false, null: false
    add_index :spree_products, :featured
  end
end
