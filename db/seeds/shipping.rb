# frozen_string_literal: true

# Idempotent — safe to run more than once.
#
# A Brazil shipping zone with a single flat rate. PROVISIONAL: it exists only
# so a Brazilian address can get through checkout at all (Solidus' sample
# data ships North America/EU zones only). Fase 3 replaces the flat rate with
# the Melhor Envio calculator — see "Freight" in docs/ARCHITECTURE.md.
module OcicoStore
  module ShippingSeed
    module_function

    def call
      brazil = Spree::Country.find_by!(iso: "BR")

      zone = Spree::Zone.find_or_create_by!(name: "Brasil") do |z|
        z.description = "Todo o território nacional"
      end
      zone.zone_members.find_or_create_by!(zoneable: brazil)

      shipping_method = Spree::ShippingMethod.find_or_initialize_by(name: "Frete fixo (provisório)")
      shipping_method.assign_attributes(
        available_to_users: true,
        zones: [ zone ],
        shipping_categories: Spree::ShippingCategory.where(name: "Default").to_a.presence ||
                             [ Spree::ShippingCategory.find_or_create_by!(name: "Default") ]
      )
      shipping_method.calculator ||= Spree::Calculator::Shipping::FlatRate.new
      shipping_method.calculator.preferred_amount = 20
      shipping_method.calculator.preferred_currency = "BRL"
      shipping_method.save!
      shipping_method
    end
  end
end

OcicoStore::ShippingSeed.call
