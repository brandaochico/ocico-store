class AddStreetNumberAndNeighborhoodToSpreeAddresses < ActiveRecord::Migration[8.1]
  def change
    add_column :spree_addresses, :street_number, :string
    add_column :spree_addresses, :neighborhood, :string
  end
end
