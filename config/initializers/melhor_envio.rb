# frozen_string_literal: true

# Melhor Envio quotes freight (Correios, Jadlog) at checkout — see "Freight" in
# docs/ARCHITECTURE.md.
#
# Same precedence as the payment initializers: Rails encrypted credentials
# first (`melhor_envio:` key), ENV as a fallback.
#
#   melhor_envio:
#     token: eyJ0eXAiOiJKV1Qi...
#     sandbox: false
#     contact_email: ...
#
# The token is a personal access token generated in the Melhor Envio panel,
# and only works in the environment it was generated in: a sandbox token is
# rejected by production and vice versa, hence the explicit `sandbox` flag
# (on everywhere but production unless said otherwise).
#
# Melhor Envio requires a User-Agent naming the application and a technical
# contact email; `contact_email` fills it in.
#
# Without a token nothing calls the API: the Melhor Envio shipping methods
# offer no rate and the fallback flat rate takes over (see
# MelhorEnvio::FallbackCalculator), so a fresh clone still checks out.
melhor_envio_credentials = Rails.application.credentials.melhor_envio || {}

sandbox = melhor_envio_credentials.fetch(:sandbox) { ENV.fetch("MELHOR_ENVIO_SANDBOX", (!Rails.env.production?).to_s) }

Rails.application.config.x.melhor_envio = {
  token: melhor_envio_credentials[:token] || ENV["MELHOR_ENVIO_TOKEN"].presence,
  sandbox: ActiveModel::Type::Boolean.new.cast(sandbox),
  contact_email: melhor_envio_credentials[:contact_email] || ENV["MELHOR_ENVIO_CONTACT_EMAIL"].presence
}

Rails.application.config.spree.calculators.shipping_methods.concat(
  %w[MelhorEnvio::ShippingCalculator MelhorEnvio::FallbackCalculator]
)
