# frozen_string_literal: true

# Idempotent — safe to run more than once (bin/rails db:seed re-runs everything).
# Seeds the store's payment methods. Created here rather than through the admin
# UI so every environment (dev, CI, production) ends up with the same record,
# reproducibly — see "Fase 2" in the architecture plan.
#
# Secrets are never stored on the record: the payment method points at the
# `solidus_stripe_env_credentials` static preference registered in
# config/initializers/solidus_stripe.rb, which reads Rails encrypted
# credentials (falling back to ENV). That means the same seeded row works in
# test and live mode, and rotating a key needs no database change.
module OcicoStore
  module PaymentMethodsSeed
    module_function

    # A method rather than a constant so that re-loading this file (db:seed is
    # re-runnable, and the specs load it repeatedly) doesn't warn about
    # redefining it.
    def stripe_preference_source
      "solidus_stripe_env_credentials"
    end

    def call
      seed_stripe
    end

    def seed_stripe
      unless stripe_credentials_configured?
        # rubocop:disable Rails/Output
        puts "Skipping Stripe payment method: no credentials configured " \
             "(set credentials.stripe.api_key or SOLIDUS_STRIPE_API_KEY)."
        # rubocop:enable Rails/Output
        return
      end

      payment_method = SolidusStripe::PaymentMethod.find_or_initialize_by(
        name: "Cartão de crédito"
      )

      payment_method.update!(
        description: "Pagamento com cartão de crédito processado pela Stripe.",
        preference_source: stripe_preference_source,
        active: true,
        available_to_users: true,
        available_to_admin: true,
        # Authorize at checkout and capture when the order ships, so a card is
        # never charged for stock we turn out not to be able to send. Import
        # duty and freight (Fase 3) can still change the total before capture.
        auto_capture: false
      )

      payment_method
    end

    def stripe_credentials_configured?
      Spree::Config.static_model_preferences
                   .for_class(SolidusStripe::PaymentMethod)
                   .key?(stripe_preference_source)
    end
  end
end

OcicoStore::PaymentMethodsSeed.call
