# frozen_string_literal: true

module OcicoAdmin
  # solidus_admin's product page plus the "Destaque na home" checkbox
  # (app/overrides/product_home_featured.rb), in the Publishing panel.
  # Registered in place of "products/show" in config/initializers/solidus_admin.rb;
  # the template is a copy of solidus_admin 0.4.0's with that one field added —
  # re-copy it when bumping solidus_admin. Translations are inherited from the
  # parent's sidecar file.
  class ProductShowComponent < SolidusAdmin::Products::Show::Component
    def self.stimulus_id
      SolidusAdmin::Products::Show::Component.stimulus_id
    end
  end
end
