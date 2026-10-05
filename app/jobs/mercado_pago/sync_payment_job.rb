# frozen_string_literal: true

module MercadoPago
  # Syncs the Spree payment(s) behind one Mercado Pago order. Enqueued by the
  # webhook and by SyncPendingPaymentsJob; safe to run any number of times
  # (see PaymentSynchronizer).
  class SyncPaymentJob < ApplicationJob
    queue_as :critical

    retry_on Client::Error, ActiveMerchant::ConnectionError, wait: :polynomially_longer, attempts: 8

    def perform(mp_order_id)
      Spree::Payment.pending.where(response_code: mp_order_id, payment_method_id: PaymentMethod.unscoped.select(:id))
                    .find_each { |payment| PaymentSynchronizer.new(payment).call }
    end
  end
end
