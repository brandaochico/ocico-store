# frozen_string_literal: true

module MelhorEnvio
  # A flat rate that is only offered when Melhor Envio can't quote: the API
  # timed out or errored, the stock location has no CEP, or no token is
  # configured (a fresh clone, or test). It keeps checkout from dead-ending
  # on "no shipping method available" while a carrier API is down.
  #
  # When the quote succeeds but *no* carrier serves the destination, the
  # fallback stays hidden too — charging a flat rate for a route nobody
  # delivers to would sell something that can't ship.
  class FallbackCalculator < ::Spree::Calculator::Shipping::FlatRate
    def self.description
      I18n.t("admin.melhor_envio.fallback_calculator_description")
    end

    def available?(package)
      !MelhorEnvio::Quote.for(package).ok?
    end
  end
end
