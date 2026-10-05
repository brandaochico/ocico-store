# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"
require Rails.root.join("spec/support/mercado_pago_api")

RSpec.describe MercadoPago::Gateway do
  let!(:store) { create(:store) }
  let(:order) { create(:order_with_line_items) }

  let(:preferences) { { access_token: "APP_USR-spec" } }
  let(:pix) { MercadoPago::PixPaymentMethod.create!(name: "Pix", preferences: preferences) }
  let(:boleto) { MercadoPago::BoletoPaymentMethod.create!(name: "Boleto", preferences: preferences) }

  let(:payment_method) { pix }
  let(:source) { MercadoPago::PaymentSource.create!(payment_method: payment_method, payer_document: document) }
  let(:document) { nil }
  let(:payment) do
    create(:payment, order: order, payment_method: payment_method, source: source, amount: 10, state: "checkout")
  end

  let(:orders_url) { "#{MercadoPagoApi::BASE}/v1/orders" }

  describe "processing a payment (Spree's authorize step)" do
    let!(:create_request) do
      stub_request(:post, orders_url).to_return(MercadoPagoApi.json(MercadoPagoApi.order_response(method: method_kind)))
    end
    let(:method_kind) { :pix }

    it "leaves the payment pending — it isn't paid until the customer pays" do
      payment.process!

      expect(payment.reload).to be_pending
      expect(payment.response_code).to eq("ORDTST01SPEC")
    end

    it "keeps the QR code on the source so the customer can be shown it" do
      payment.process!

      expect(source.reload).to have_attributes(
        mp_order_id: "ORDTST01SPEC",
        mp_payment_id: "PAY01SPEC",
        qr_code: start_with("000201"),
        qr_code_base64: be_present,
        expires_at: Time.zone.parse("2026-10-05T05:00:00Z")
      )
    end

    it "uses the Spree payment as the idempotency key, so a retry can't create a second charge" do
      payment.process!

      expect(create_request.with(headers: { "X-Idempotency-Key" => "#{order.number}-#{payment.number}" }))
        .to have_been_made.once
    end

    it "charges the payment amount as a Pix that expires in 4 hours" do
      payment.process!

      expect(
        a_request(:post, orders_url).with do |request|
          body = JSON.parse(request.body)
          charge = body.dig("transactions", "payments", 0)

          body["total_amount"] == "10.00" &&
            body["external_reference"] == "#{order.number}-#{payment.number}" &&
            body.dig("payer", "email") == order.email &&
            charge["payment_method"] == { "id" => "pix", "type" => "bank_transfer" } &&
            charge["expiration_time"] == "PT4H"
        end
      ).to have_been_made
    end

    context "with Boleto" do
      let(:payment_method) { boleto }
      let(:method_kind) { :boleto }
      let(:document) { "529.982.247-25" }

      before do
        # Spree addresses are immutable — a changed address is a new record.
        order.update!(bill_address: create(:address, name: "Ana Maria Silva", address1: "Av. Paulista, 1000", address2: "Bela Vista"))
      end

      it "sends the payer's CPF and address, and keeps the boleto line" do
        payment.process!

        expect(
          a_request(:post, orders_url).with do |request|
            payer = JSON.parse(request.body)["payer"]

            payer["first_name"] == "Ana" && payer["last_name"] == "Maria Silva" &&
              payer["identification"] == { "type" => "CPF", "number" => "52998224725" } &&
              payer["address"].slice("street_name", "street_number", "neighborhood") ==
                { "street_name" => "Av. Paulista", "street_number" => "1000", "neighborhood" => "Bela Vista" }
          end
        ).to have_been_made
        expect(source.reload.digitable_line).to eq("23793380296060104310602006333302615920000005000")
      end

      it "falls back to S/N when the street line has no number" do
        order.update!(bill_address: create(:address, address1: "Rua sem número", address2: nil))

        payment.process!

        expect(
          a_request(:post, orders_url).with do |request|
            JSON.parse(request.body).dig("payer", "address").slice("street_number", "neighborhood") ==
              { "street_number" => "S/N", "neighborhood" => "-" }
          end
        ).to have_been_made
      end
    end

    context "when Mercado Pago rejects the charge" do
      let!(:create_request) do
        stub_request(:post, orders_url).to_return(
          MercadoPagoApi.json({ "errors" => [ { "code" => "invalid", "message" => "Invalid payer" } ] }, status: 400)
        )
      end

      it "fails the payment with Mercado Pago's message" do
        expect { payment.process! }.to raise_error(Spree::Core::GatewayError, /Invalid payer/)
        expect(payment.reload).to be_failed
      end
    end

    context "when Mercado Pago can't be reached" do
      let!(:create_request) { stub_request(:post, orders_url).to_timeout }

      it "raises the gateway's connection error instead of a 500" do
        expect { payment.process! }.to raise_error(Spree::Core::GatewayError)
      end
    end
  end

  describe "voiding an unpaid charge" do
    before { payment.update!(state: "pending", response_code: "ORDTST01SPEC") }

    it "cancels the Mercado Pago order so it can no longer be paid" do
      cancel = stub_request(:post, "#{orders_url}/ORDTST01SPEC/cancel")
        .to_return(MercadoPagoApi.json(MercadoPagoApi.order_response(status: "canceled")))

      payment.void_transaction!

      expect(cancel).to have_been_made
      expect(payment.reload).to be_void
    end
  end

  describe "refunding" do
    before do
      source.update!(mp_order_id: "ORDTST01SPEC", mp_payment_id: "PAY01SPEC")
      payment.update!(state: "completed", response_code: "ORDTST01SPEC")
    end

    let(:reason) { create(:refund_reason) }

    it "refunds just the requested amount of the Mercado Pago payment" do
      refund_request = stub_request(:post, "#{orders_url}/ORDTST01SPEC/refund")
        .with(body: { transactions: [ { id: "PAY01SPEC", amount: "4.00" } ] })
        .to_return(MercadoPagoApi.json(MercadoPagoApi.order_response(
          status: "processed", refunds: [ { "id" => "REF01SPEC", "amount" => "4.00", "status" => "processed" } ]
        )))

      refund = payment.refunds.create!(amount: 4, reason: reason)
      refund.perform!

      expect(refund_request).to have_been_made.once
      expect(refund.reload.transaction_id).to eq("REF01SPEC")
    end
  end
end
