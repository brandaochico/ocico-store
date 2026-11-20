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

# When to ask the card's bank for 3D Secure authentication, sent with every
# PaymentIntent (app/overrides/stripe_intent_without_payment_method_types.rb):
#
#   any        always request it; the bank still decides whether to challenge
#              the customer (app confirmation, SMS) or approve frictionlessly
#   automatic  only when Stripe or the bank requires it (Stripe's default)
#
# Production runs `any` for the store's first weeks (STRIPE_REQUEST_THREE_D_SECURE
# in config/deploy.yml): a brand-new merchant's unauthenticated card payments
# get declined by issuers (Nubank refused the first live test purchase with
# do_not_honor), and authenticated ones shift fraud liability to the bank.
# Included at no extra cost on Stripe's standard Brazilian pricing (checked
# 2026-11-20; custom-priced accounts pay per attempt).
stripe_three_d_secure = ENV.fetch("STRIPE_REQUEST_THREE_D_SECURE", "automatic")
unless %w[any automatic].include?(stripe_three_d_secure)
  raise ArgumentError, "STRIPE_REQUEST_THREE_D_SECURE must be any or automatic, got #{stripe_three_d_secure.inspect}"
end
Rails.application.config.x.stripe_request_three_d_secure = stripe_three_d_secure
