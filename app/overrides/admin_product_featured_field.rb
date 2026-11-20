# frozen_string_literal: true

# The "Destaque na home" checkbox on the classic admin's product form, right
# after "Promotable" (app/overrides/product_home_featured.rb).
module AdminProductFeaturedField
  Deface::Override.new(
    virtual_path: "spree/admin/products/_form",
    name: "admin_product_featured_field",
    insert_after: "[data-hook='admin_product_form_promotionable']",
    partial: "spree/admin/products/featured_field"
  )
end
