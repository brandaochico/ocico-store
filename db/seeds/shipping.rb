# frozen_string_literal: true

# Idempotent — safe to run more than once.
#
# The Brazil shipping zone and its shipping methods:
#
# - one per Melhor Envio carrier service (MelhorEnvio::ShippingCalculator),
#   each offered only when that carrier can take the shipment;
# - "Entrega padrão", a flat rate offered only when Melhor Envio can't quote
#   at all (MelhorEnvio::FallbackCalculator) — it used to be the provisional
#   "Frete fixo (provisório)", which is converted in place.
#
# Melhor Envio quotes from the stock location's CEP: the store dispatches from
# Canoas/RS (CEP 92020-300). The seed fills that in only while the stock
# location has no CEP, so an address edited in the admin (Estoque → Locais de
# estoque) is never overwritten. See "Freight" in docs/ARCHITECTURE.md.
module OcicoStore
  module ShippingSeed
    module_function

    # Methods, not constants: specs load this file once per example, and a
    # constant would be redefined (with a warning) every time.

    # Melhor Envio service id => name shown at checkout.
    def melhor_envio_services
      {
        1 => "Correios PAC",
        2 => "Correios SEDEX",
        3 => "Jadlog .Package",
        17 => "Correios Mini Envios"
      }
    end

    def fallback_name = "Entrega padrão"
    def fallback_amount = 20
    def provisional_name = "Frete fixo (provisório)"

    def call
      zone = seed_zone
      categories = shipping_categories

      melhor_envio_services.each do |service_id, name|
        seed_melhor_envio_method(service_id, name, zone:, categories:)
      end
      seed_fallback_method(zone:, categories:)
      seed_dispatch_origin
    end

    def dispatch_origin
      { zipcode: "92020-300", city: "Canoas", state_abbr: "RS" }
    end

    def seed_dispatch_origin
      stock_location = Spree::StockLocation.order(:id).first
      return if stock_location.nil? || stock_location.zipcode.present?

      brazil = Spree::Country.find_by!(iso: "BR")
      stock_location.update!(
        zipcode: dispatch_origin[:zipcode],
        city: dispatch_origin[:city],
        country: brazil,
        state: brazil.states.find_by(abbr: dispatch_origin[:state_abbr])
      )
    end

    def seed_zone
      brazil = Spree::Country.find_by!(iso: "BR")

      zone = Spree::Zone.find_or_create_by!(name: "Brasil") do |z|
        z.description = "Todo o território nacional"
      end
      zone.zone_members.find_or_create_by!(zoneable: brazil)
      zone
    end

    def shipping_categories
      [ Spree::ShippingCategory.find_or_create_by!(name: "Default") ]
    end

    # Matched by service id rather than name, so renaming a method in the
    # admin doesn't make the next seed create a duplicate.
    def seed_melhor_envio_method(service_id, name, zone:, categories:)
      shipping_method = Spree::ShippingMethod
        .joins(:calculator)
        .where(spree_calculators: { type: "MelhorEnvio::ShippingCalculator" })
        .find { |method| method.calculator.preferred_service_id == service_id }
      shipping_method ||= Spree::ShippingMethod.new(
        name:,
        available_to_users: true,
        calculator: MelhorEnvio::ShippingCalculator.new(preferred_service_id: service_id)
      )

      shipping_method.zones = [ zone ]
      shipping_method.shipping_categories = categories if shipping_method.shipping_categories.empty?
      shipping_method.calculator.preferred_currency = "BRL"
      shipping_method.save!
    end

    def seed_fallback_method(zone:, categories:)
      shipping_method = Spree::ShippingMethod.find_by(name: fallback_name) ||
                        Spree::ShippingMethod.find_by(name: provisional_name) ||
                        Spree::ShippingMethod.new(available_to_users: true)

      shipping_method.name = fallback_name
      shipping_method.zones = [ zone ]
      shipping_method.shipping_categories = categories if shipping_method.shipping_categories.empty?

      unless shipping_method.calculator.is_a?(MelhorEnvio::FallbackCalculator)
        shipping_method.calculator = MelhorEnvio::FallbackCalculator.new(
          preferred_amount: fallback_amount, preferred_currency: "BRL"
        )
      end
      shipping_method.save!
    end
  end
end

OcicoStore::ShippingSeed.call
