# frozen_string_literal: true

module OcicoAdmin
  # solidus_admin's address form plus street number and neighbourhood
  # (app/overrides/brazilian_address.rb). Registered in place of
  # "ui/forms/address" in config/initializers/solidus_admin.rb; the template
  # is a copy of solidus_admin 0.4.0's with those two fields added.
  class AddressFormComponent < SolidusAdmin::UI::Forms::Address::Component
    # Keep the parent's Stimulus controller (it reloads the state list when
    # the country changes); the default would derive a new id from this name.
    def self.stimulus_id
      SolidusAdmin::UI::Forms::Address::Component.stimulus_id
    end
  end
end
