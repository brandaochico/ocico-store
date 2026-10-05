# frozen_string_literal: true

module MercadoPago
  # Backstop for webhooks: periodically re-syncs every pending Pix/Boleto
  # payment (config/recurring.yml), so a missed or misconfigured notification
  # delays a status change but never loses it — most importantly, expired
  # charges still get their stock released.
  class SyncPendingPaymentsJob < ApplicationJob
    queue_as :low

    def perform
      Spree::Payment.pending
                    .where(payment_method_id: PaymentMethod.unscoped.select(:id))
                    .where.not(response_code: [ nil, "" ])
                    .pluck(:response_code)
                    .uniq
                    .each { |mp_order_id| SyncPaymentJob.perform_later(mp_order_id) }
    end
  end
end
