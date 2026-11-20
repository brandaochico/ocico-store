# frozen_string_literal: true

# Emails the customer when money goes back to them.
#
# Solidus only emails about refunds made through a return (reimbursement
# mailer); a refund from the admin's Payments tab, a paid order's
# cancellation or a refund made straight in Stripe's dashboard (synced by the
# charge.refunded webhook) went out silently. The trigger is the refund
# getting its gateway transaction id: Spree::Refund#perform! stores it only
# once Stripe or Mercado Pago accepted the refund, and the Stripe sync creates
# the row with it — so a refund the gateway rejected never emails anyone.
module RefundCustomerNotification
  def self.prepended(base)
    base.after_commit :notify_customer_of_refund, on: [ :create, :update ], if: :refund_just_processed?
  end

  private

  def refund_just_processed?
    saved_change_to_transaction_id? && transaction_id.present? &&
      reimbursement_id.nil? # returns already get Spree's reimbursement email
  end

  def notify_customer_of_refund
    RefundMailer.refund_email(self).deliver_later
  end

  ::Spree::Refund.prepend self
end
