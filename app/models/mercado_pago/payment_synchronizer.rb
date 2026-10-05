# frozen_string_literal: true

module MercadoPago
  # Brings one pending Pix/Boleto Spree::Payment in line with its Mercado Pago
  # order: completes it once paid, fails it (and cancels the Spree order,
  # releasing its stock) once it can no longer be paid.
  #
  # Always reads the order's status from the API, never from a webhook body, so
  # a forged or stale notification can't move money state. Idempotent by
  # construction: the transition only runs on a payment that is still pending,
  # checked inside a row lock, so duplicate or concurrent webhook deliveries
  # and the periodic sweep can all call this for the same payment safely.
  class PaymentSynchronizer
    UNPAYABLE_STATUSES = %w[expired canceled failed].freeze

    def initialize(payment)
      @payment = payment
    end

    def call
      return unless @payment.pending? && @payment.response_code.present?

      mp_order = client.get_order(@payment.response_code)

      @payment.with_lock do
        next unless @payment.pending?

        case mp_order["status"]
        when "processed" then complete(mp_order)
        when *UNPAYABLE_STATUSES then fail_and_release_stock
        end
      end
    end

    private

    def complete(mp_order)
      paid = BigDecimal(mp_order["total_paid_amount"].presence || "0")

      if paid < @payment.amount
        Rails.logger.error(
          "[MercadoPago] order #{mp_order["id"]} processed with #{paid}, " \
          "less than payment #{@payment.number}'s #{@payment.amount}; leaving it pending"
        )
        return
      end

      @payment.capture_events.create!(amount: @payment.amount)
      @payment.complete!
    end

    def fail_and_release_stock
      @payment.failure!

      order = @payment.order
      return if order.paid? || !order.can_cancel?

      # Cancelling restocks the order's inventory and emails the customer.
      order.cancel!
    end

    def client
      Client.new(access_token: @payment.payment_method.preferred_access_token)
    end
  end
end
