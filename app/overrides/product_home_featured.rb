# frozen_string_literal: true

# The "Destaque na home" flag (spree_products.featured): editable from both
# admins and picked up by HomeController. The `featured` scope itself lives in
# app/overrides/product_featured_similar_products.rb.
#
# The classic admin filters product params through Solidus's permitted
# attributes, so the flag must be on that list; solidus_admin permits all.
# Its checkbox is added to each admin's product form by
# app/overrides/admin_product_featured_field.rb (classic, Deface) and
# OcicoAdmin::ProductShowComponent (solidus_admin).
module ProductHomeFeatured
  ::Spree::PermittedAttributes.product_attributes << :featured
end
