# frozen_string_literal: true

SolidusStripe.configure do |config|
  # List of webhook events you want to handle.
  # For instance, if you want to handle the `payment_intent.succeeded` event,
  # you should add it to the list below. A corresponding
  # `:"stripe.payment_intent.succeeded"` event will be published in `Spree::Bus`
  # whenever a `payment_intent.succeeded` event is received from Stripe.
  # config.webhook_events = %i[payment_intent.succeeded]
  #
  # Number of seconds while a webhook event is valid after its creation.
  # Defaults to the same value as Stripe's default.
  # config.webhook_signature_tolerance = 150
  #
  # Name of the `Spree::RefundReason` used for Stripe-generated refunds.
  # Defaults to {SolidusStripe::DEFAULT_STRIPE_REFUND_REASON_NAME}. If you
  # change it, make sure that the corresponding `Spree::RefundReason` exists in
  # the database with that name.
  # config.refund_reason_name = "Stripe refund"
end

# Stripe credentials.
#
# The upstream generator reads these straight from ENV. We prefer Rails
# encrypted credentials (`config/credentials.yml.enc`, `stripe:` key) and keep
# ENV only as a fallback, so CI and Kamal can inject secrets without shipping
# the master key:
#
#   stripe:
#     api_key: sk_test_...
#     publishable_key: pk_test_...
#     webhook_signing_secret: whsec_...
#
# When neither source is configured the static preference is simply not
# registered — the app boots fine, there's just no Stripe option to pick in the
# admin. `test_mode` is derived from the key prefix rather than configured
# separately, so a live key can never be silently treated as a test key.
stripe_credentials = Rails.application.credentials.stripe || {}
stripe_api_key = stripe_credentials[:api_key] || ENV["SOLIDUS_STRIPE_API_KEY"]

if stripe_api_key.present?
  Spree::Config.static_model_preferences.add(
    "SolidusStripe::PaymentMethod",
    "solidus_stripe_env_credentials",
    api_key: stripe_api_key,
    publishable_key: stripe_credentials[:publishable_key] || ENV["SOLIDUS_STRIPE_PUBLISHABLE_KEY"],
    test_mode: stripe_api_key.start_with?("sk_test_"),
    webhook_endpoint_signing_secret:
      stripe_credentials[:webhook_signing_secret] || ENV["SOLIDUS_STRIPE_WEBHOOK_SIGNING_SECRET"]
  )
end
