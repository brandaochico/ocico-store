# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"

# app/overrides/refund_customer_notification.rb: the customer hears about every
# refund that actually went through — and only those.
RSpec.describe "Refund email to the customer" do
  let!(:store) { create(:store) }
  let(:order) { create(:completed_order_with_totals, store:) }
  let(:payment) { create(:payment, order:, state: "completed", amount: order.total) }
  let(:reason) { create(:refund_reason) }

  def new_refund(amount = 5)
    Spree::Refund.new(payment:, amount:, reason:)
  end

  it "is sent once the gateway accepts a refund made in the admin" do
    refund = new_refund
    refund.save!

    expect { refund.perform! }.to have_enqueued_mail(RefundMailer, :refund_email).with(refund)
  end

  it "is not sent when the gateway rejects the refund" do
    refund = new_refund
    refund.save!
    allow(payment.payment_method).to receive(:credit)
      .and_return(ActiveMerchant::Billing::Response.new(false, "declined", {}))
    allow(refund).to receive(:payment).and_return(payment)

    expect { refund.perform! rescue Spree::Core::GatewayError }.not_to have_enqueued_mail(RefundMailer, :refund_email)
  end

  it "is sent for a refund synced from Stripe's dashboard (created already processed)" do
    expect { new_refund.tap { |r| r.transaction_id = "re_dashboard" }.save! }
      .to have_enqueued_mail(RefundMailer, :refund_email)
  end

  it "is sent only once, not on later updates of the same refund" do
    refund = new_refund
    refund.save!
    refund.perform!

    expect { refund.update!(amount: 4) }.not_to have_enqueued_mail(RefundMailer, :refund_email)
  end

  it "is not sent for a return's refund, which gets Spree's own reimbursement email" do
    reimbursement = create(:reimbursement)
    return_payment = create(:payment, order: reimbursement.order, state: "completed", amount: 50)
    refund = Spree::Refund.new(payment: return_payment, amount: 5, reason:, reimbursement:, transaction_id: "re_return")

    expect { refund.save! }.not_to have_enqueued_mail(RefundMailer, :refund_email)
  end
end
