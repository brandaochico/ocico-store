# frozen_string_literal: true

# Whether an order has been refunded, in full or in part.
#
# Solidus has no such state: a refund lowers payment_total, so a fully
# refunded order reads as "balance due", indistinguishable from an unpaid one.
# The order page, the account's order list and the refund email use this to
# say it plainly. Refunds are compared with what was actually collected
# (completed payments), not with the order total, which a cancellation can
# change afterwards.
module OrderRefundStatus
  # :refunded, :partially_refunded or nil.
  def refund_status
    refunded = refund_total
    return if refunded.zero?

    refunded >= payments.completed.sum(:amount) ? :refunded : :partially_refunded
  end

  def display_refund_total
    Spree::Money.new(refund_total, currency:)
  end

  ::Spree::Order.prepend self
end
