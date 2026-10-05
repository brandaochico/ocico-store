# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"
require Rails.root.join("spec/support/mercado_pago_api")

# The storefront half of Pix/Boleto: choosing it at the payment step,
# completing the order (which creates the charge), and the order page then
# showing the customer how to pay.
RSpec.describe "Paying with Pix or Boleto", type: :request, with_signed_in_user: true do
  let(:user) { order.user }
  let(:order) { create(:order_with_line_items, state: "payment") }
  let(:preferences) { { access_token: "APP_USR-spec" } }
  let!(:pix) { MercadoPago::PixPaymentMethod.create!(name: "Pix", preferences: preferences) }
  let!(:boleto) { MercadoPago::BoletoPaymentMethod.create!(name: "Boleto", preferences: preferences) }

  def choose(payment_method, payer_document: "")
    patch update_checkout_path(state: "payment"), params: {
      order: { payments_attributes: [ { payment_method_id: payment_method.id.to_s } ] },
      payment_source: { payment_method.id.to_s => { payer_document: payer_document } }
    }
  end

  it "offers both at the payment step" do
    get checkout_state_path("payment")

    expect(response.body).to include("Pix", "Boleto", "CPF ou CNPJ do pagador")
  end

  context "with Pix" do
    before do
      stub_request(:post, "#{MercadoPagoApi::BASE}/v1/orders")
        .to_return(MercadoPagoApi.json(MercadoPagoApi.order_response(amount: format("%.2f", order.total))))
    end

    it "creates the charge only when the order is confirmed, then shows the QR code" do
      choose(pix)
      expect(order.reload.state).to eq("confirm")
      expect(a_request(:post, %r{/v1/orders})).not_to have_been_made

      patch update_checkout_path(state: "confirm")

      order.reload
      expect(order).to be_complete
      expect(order.payments.last).to be_pending
      expect(order.payment_state).to eq("balance_due")

      get order_path(order)
      expect(response.body).to include("Pague com Pix", "00020126580014br.gov.bcb.pix0136spec", "data:image/png;base64,")
    end
  end

  context "with Boleto" do
    it "won't move on without a valid CPF/CNPJ" do
      choose(boleto, payer_document: "123.456.789-00")

      expect(order.reload.state).to eq("payment")
      expect(order.payments).to be_empty
    end

    it "shows the boleto line once the order is confirmed" do
      stub_request(:post, "#{MercadoPagoApi::BASE}/v1/orders")
        .to_return(MercadoPagoApi.json(MercadoPagoApi.order_response(method: :boleto, status_detail: "waiting_payment")))

      choose(boleto, payer_document: "529.982.247-25")
      patch update_checkout_path(state: "confirm")

      get order_path(order.reload)
      expect(response.body).to include("Pague o boleto", "23793380296060104310602006333302615920000005000")
    end
  end
end
