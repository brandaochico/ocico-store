# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"
require Rails.root.join("spec/support/mercado_pago_api")

RSpec.describe "Mercado Pago sync jobs" do
  let!(:store) { create(:store) }
  let(:pix) { MercadoPago::PixPaymentMethod.create!(name: "Pix", preferences: { access_token: "APP_USR-spec" }) }

  def mp_payment(mp_order_id, state: "pending")
    source = MercadoPago::PaymentSource.create!(payment_method: pix, mp_order_id: mp_order_id)
    create(:payment, payment_method: pix, source: source, response_code: mp_order_id, state: state)
  end

  describe MercadoPago::SyncPaymentJob do
    it "syncs the pending payment behind that Mercado Pago order" do
      payment = mp_payment("ORDTST01SPEC")
      stub_request(:get, "#{MercadoPagoApi::BASE}/v1/orders/ORDTST01SPEC")
        .to_return(MercadoPagoApi.json(MercadoPagoApi.order_response(
          status: "processed", amount: format("%.2f", payment.amount), paid_amount: format("%.2f", payment.amount)
        )))

      described_class.perform_now("ORDTST01SPEC")

      expect(payment.reload).to be_completed
    end

    it "does nothing for an order that isn't ours" do
      described_class.perform_now("ORDTST01UNKNOWN")

      expect(a_request(:get, %r{/v1/orders/})).not_to have_been_made
    end
  end

  describe MercadoPago::SyncPendingPaymentsJob do
    it "enqueues a sync for every pending Pix/Boleto payment, and only those" do
      mp_payment("ORDTST01A")
      mp_payment("ORDTST01B")
      mp_payment("ORDTST01DONE", state: "completed")
      create(:payment, state: "pending", response_code: "card-123")

      expect { described_class.perform_now }
        .to have_enqueued_job(MercadoPago::SyncPaymentJob).exactly(2).times
      expect(MercadoPago::SyncPaymentJob).to have_been_enqueued.with("ORDTST01A")
      expect(MercadoPago::SyncPaymentJob).to have_been_enqueued.with("ORDTST01B")
    end
  end
end
