class AddDeliveryDaysToSpreeShippingRates < ActiveRecord::Migration[8.1]
  def change
    add_column :spree_shipping_rates, :min_delivery_days, :integer
    add_column :spree_shipping_rates, :max_delivery_days, :integer
  end
end
