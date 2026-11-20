# frozen_string_literal: true

module MelhorEnvio
  # Prices one Melhor Envio carrier service (PAC, SEDEX, ...) for a package.
  # One Spree::ShippingMethod per service, each with this calculator and the
  # service's Melhor Envio id (db/seeds/shipping.rb):
  #
  #   1  Correios PAC        2  Correios SEDEX
  #   3  Jadlog .Package    17  Correios Mini Envios
  #  31  Loggi Express      34  Loggi Ponto
  #
  # A service that can't take the shipment (destination not served, over its
  # declared-value or weight limit — Mini Envios stops at R$100 and 300 g) is
  # simply not offered: Solidus skips a method whose calculator says it's not
  # available.
  class ShippingCalculator < ::Spree::ShippingCalculator
    preference :service_id, :integer
    # Melhor Envio prices in BRL; Solidus's estimator skips a calculator whose
    # currency doesn't match the order's.
    preference :currency, :string, default: -> { Spree::Config[:currency] }

    def self.description
      I18n.t("admin.melhor_envio.calculator_description")
    end

    def available?(package)
      rate(package).present?
    end

    def compute_package(package)
      rate(package)&.price
    end

    # [min, max] business days, shown next to the price at checkout.
    def delivery_days(package)
      found = rate(package)
      [ found.min_days, found.max_days ] if found&.min_days
    end

    private

    def rate(package)
      MelhorEnvio::Quote.for(package).rate_for(preferred_service_id)
    end
  end
end
