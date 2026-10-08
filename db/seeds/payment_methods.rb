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

    def mercado_pago_preference_source
      "mercado_pago_env_credentials"
    end

    def call
      seed_stripe
      seed_mercado_pago
    end

    # Pix and Boleto go through Mercado Pago rather than Stripe: Stripe's Pix
    # is invite-only for Brazilian accounts and its Boleto can't be refunded.
    # Not offered in the admin's "new payment" form — an admin can't scan a QR
    # code on the customer's behalf.
    def seed_mercado_pago
      unless mercado_pago_credentials_configured?
        # rubocop:disable Rails/Output
        puts "Skipping Pix/Boleto payment methods: no Mercado Pago credentials configured " \
             "(set credentials.mercado_pago.access_token or MERCADOPAGO_ACCESS_TOKEN)."
        # rubocop:enable Rails/Output
        return
      end

      # Listed (and so offered) in this order, Pix first: the checkout's
      # payment step pre-selects whichever method comes first.
      {
        MercadoPago::PixPaymentMethod => [ "Pix", "Pagamento instantâneo via Pix, processado pelo Mercado Pago." ],
        MercadoPago::BoletoPaymentMethod => [ "Boleto", "Boleto bancário, processado pelo Mercado Pago." ]
      }.each_with_index.map do |(klass, (name, description)), index|
        payment_method = klass.find_or_initialize_by(name: name)
        payment_method.update!(
          description: description,
          preference_source: mercado_pago_preference_source,
          active: true,
          available_to_users: true,
          available_to_admin: false
        )
        payment_method.insert_at(index + 1)
        payment_method
      end
    end

    def mercado_pago_credentials_configured?
      [ MercadoPago::PixPaymentMethod, MercadoPago::BoletoPaymentMethod ].all? do |klass|
        Spree::Config.static_model_preferences.for_class(klass).key?(mercado_pago_preference_source)
      end
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
