# frozen_string_literal: true

# Mercado Pago handles Pix and Boleto (cards stay on Stripe) — see "Payment" in
# docs/ARCHITECTURE.md for why.
#
# Same precedence as config/initializers/solidus_stripe.rb: Rails encrypted
# credentials first (`mercado_pago:` key), ENV as a fallback.
#
#   mercado_pago:
#     access_token: APP_USR-...
#     public_key: APP_USR-...
#     webhook_secret: ...
#
# Sandbox uses the production-style APP_USR credentials of a Mercado Pago
# *test seller account*; the old TEST-... credentials are rejected by the
# Orders API.
mercado_pago_credentials = Rails.application.credentials.mercado_pago || {}

Rails.application.config.x.mercado_pago = {
  access_token: mercado_pago_credentials[:access_token] || ENV["MERCADOPAGO_ACCESS_TOKEN"],
  public_key: mercado_pago_credentials[:public_key] || ENV["MERCADOPAGO_PUBLIC_KEY"],
  webhook_secret: mercado_pago_credentials[:webhook_secret] || ENV["MERCADOPAGO_WEBHOOK_SECRET"],
  # Sandbox rejects a payer email that belongs to a real Mercado Pago account.
  # Never set in production.
  test_payer_email: ENV["MERCADOPAGO_TEST_PAYER_EMAIL"].presence
}

mercado_pago_payment_methods = %w[MercadoPago::PixPaymentMethod MercadoPago::BoletoPaymentMethod]

Rails.application.config.spree.payment_methods.concat(mercado_pago_payment_methods)

# CPF/CNPJ typed in at the payment step (required by Boleto).
Spree::PermittedAttributes.source_attributes << :payer_document

# As with Stripe, no secret is ever written to the payment method rows: they
# point at this static preference. Not registered without an access token, so a
# fresh clone boots fine and simply offers no Pix/Boleto.
if Rails.application.config.x.mercado_pago[:access_token].present?
  mercado_pago_payment_methods.each do |klass|
    Spree::Config.static_model_preferences.add(
      klass,
      "mercado_pago_env_credentials",
      access_token: Rails.application.config.x.mercado_pago[:access_token],
      public_key: Rails.application.config.x.mercado_pago[:public_key]
    )
  end
end
