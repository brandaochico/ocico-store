# frozen_string_literal: true

# Tells the customer a refund went through — sent by
# app/overrides/refund_customer_notification.rb. A Spree::BaseMailer so it
# gets the store's sender, reply-to and subject handling
# (app/overrides/store_mailer_headers.rb), like the order emails.
class RefundMailer < Spree::BaseMailer
  def refund_email(refund)
    @refund = refund
    @order = refund.payment.order
    @store = @order.store
    @full = @order.refund_status == :refunded
    # An account's order opens after logging in; a guest's only with its token.
    @order_link = @order.user_id ? order_url(@order) : token_order_url(@order, @order.guest_token)

    mail(to: @order.email, from: from_address(@store), subject: "#{@store.name} #{t(".subject")} ##{@order.number}")
  end
end
