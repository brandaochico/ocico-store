# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"
require Rails.root.join("spec/support/mercado_pago_api")

# Every Pix/Boleto money-state transition happens here, triggered by webhooks
# (at-least-once, possibly concurrent) and by a periodic sweep — so "applies
# the right transition exactly once" is the property pinned down below.
RSpec.describe MercadoPago::PaymentSynchronizer do
  subject(:sync) { described_class.new(payment).call }

  let!(:store) { create(:store) }
  let(:order) { create(:completed_order_with_totals) }
  let(:pix) { MercadoPago::PixPaymentMethod.create!(name: "Pix", preferences: { access_token: "APP_USR-spec" }) }
  let(:source) { MercadoPago::PaymentSource.create!(payment_method: pix, mp_order_id: "ORDTST01SPEC") }
  let!(:payment) do
    create(:payment, order: order, payment_method: pix, source: source, amount: order.total,
                     state: "pending", response_code: "ORDTST01SPEC")
  end

  let(:amount) { format("%.2f", order.total) }

  def stub_mp_order(**attributes)
    stub_request(:get, "#{MercadoPagoApi::BASE}/v1/orders/ORDTST01SPEC")
      .to_return(MercadoPagoApi.json(MercadoPagoApi.order_response(amount: amount, **attributes)))
  end

  before { order.recalculate }

  context "when the customer has paid" do
    before { stub_mp_order(status: "processed", status_detail: "accredited", paid_amount: amount) }

    it "completes the payment and marks the order paid" do
      sync

      expect(payment.reload).to be_completed
      expect(order.reload.payment_state).to eq("paid")
    end

    it "records the capture, so refunds have something to refund against" do
      expect { sync }.to change { payment.capture_events.count }.by(1)
    end

    it "does nothing the second time (duplicate webhook delivery)" do
      described_class.new(payment).call

      expect { described_class.new(payment.reload).call }.not_to change { payment.capture_events.count }
      expect(a_request(:get, %r{/v1/orders/})).to have_been_made.once
    end
  end

  context "when Mercado Pago reports less paid than the payment's amount" do
    before { stub_mp_order(status: "processed", paid_amount: "1.00") }

    it "leaves the payment pending instead of marking the order paid" do
      sync

      expect(payment.reload).to be_pending
    end
  end

  context "when the charge is still waiting for the customer" do
    before { stub_mp_order(status: "action_required") }

    it "changes nothing" do
      expect { sync }.not_to change { [ payment.reload.state, order.reload.state ] }
    end
  end

  %w[expired canceled failed].each do |status|
    context "when the charge is #{status}" do
      before { stub_mp_order(status: status) }

      it "fails the payment" do
        sync

        expect(payment.reload).to be_failed
      end

      it "cancels the order, putting its stock back on sale" do
        variant = order.line_items.first.variant

        expect { sync }.to change { variant.reload.total_on_hand }.by(order.line_items.first.quantity)
        expect(order.reload).to be_canceled
      end
    end
  end

  it "never calls Mercado Pago for a payment that isn't pending" do
    payment.update_columns(state: "completed")

    sync

    expect(a_request(:get, %r{/v1/orders/})).not_to have_been_made
  end
end
