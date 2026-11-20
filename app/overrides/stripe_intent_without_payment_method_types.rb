# frozen_string_literal: true

# Stops sending `payment_method_types` when creating or updating a Stripe
# PaymentIntent.
#
# solidus_stripe passes `payment_method_types: [<the card's type>]` alongside
# the customer and the already-chosen PaymentMethod. Stripe accounts created
# from late 2026 on reject that combination outright ("The
# `payment_method_types` parameter is no longer supported. Payment methods are
# now managed from your Dashboard settings"), which broke checkout's confirm
# step with a 500 on the live account (2026-11-20). The test-mode account,
# being older, still accepted it.
#
# Leaving it out changes nothing in practice: the intent already names its
# PaymentMethod, and on the API version stripe-ruby 8.x pins (2022-11-15)
# Stripe then defaults the types to ["card"] — checked against the live
# account. Both methods below are upstream's (solidus_stripe 5.0.2, ref
# cdf1784) minus that one key — plus, on creation, the 3D Secure option —
# so re-check them when bumping the gem.
module StripeIntentWithoutPaymentMethodTypes
  def create_stripe_intent(payment, **stripe_intent_options)
    stripe_customer_id = ::SolidusStripe::Customer.retrieve_or_create_stripe_customer_id(
      payment_method: payment_method,
      order: order
    )

    payment_method.gateway.request do
      ::Stripe::PaymentIntent.create({
        amount: stripe_order_amount,
        currency: order.currency,
        capture_method: payment_method.auto_capture? ? "automatic" : "manual",
        setup_future_usage: payment_method.preferred_setup_future_usage.presence,
        customer: stripe_customer_id,
        payment_method: payment.source.stripe_payment_method_id,
        # Not upstream: see config.x.stripe_request_three_d_secure in
        # config/initializers/solidus_stripe.rb.
        payment_method_options: {
          card: { request_three_d_secure: Rails.configuration.x.stripe_request_three_d_secure }
        },
        metadata: { solidus_order_number: order.number },
        **stripe_intent_options
      })
    end
  end

  module ClassMethods
    def retrieve_for_payment(payment)
      intent = where(payment_method: payment.payment_method, order: payment.order).last

      return unless intent&.usable?

      # Update the intent with the previously acquired payment method.
      intent.payment_method.gateway.request do
        ::Stripe::PaymentIntent.update(
          intent.stripe_intent_id,
          payment_method: payment.source.stripe_payment_method_id
        )
      end

      intent
    end
  end

  ::SolidusStripe::PaymentIntent.prepend self
  ::SolidusStripe::PaymentIntent.singleton_class.prepend ClassMethods
end
