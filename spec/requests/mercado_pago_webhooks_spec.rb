# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"

RSpec.describe "Mercado Pago webhooks", type: :request do
  let(:secret) { "webhook-secret" }
  let(:data_id) { "ORD01SPEC" }
  let(:request_id) { "req-123" }
  let(:ts) { "1742505638683" }
  let(:body) { { action: "order.processed", type: "order", data: { id: data_id, status: "processed" } } }

  around do |example|
    config = Rails.configuration.x.mercado_pago
    original = config[:webhook_secret]
    config[:webhook_secret] = secret
    example.run
    config[:webhook_secret] = original
  end

  def deliver(signature: OpenSSL::HMAC.hexdigest("SHA256", secret, "id:#{data_id};request-id:#{request_id};ts:#{ts};"),
              payload: body)
    post "/webhooks/mercado_pago?data.id=#{data_id}&type=order",
      params: payload.to_json,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "x-signature" => "ts=#{ts},v1=#{signature}",
        "x-request-id" => request_id
      }
  end

  context "with a valid signature" do
    it "acknowledges and enqueues a sync of that order, on the critical queue" do
      expect { deliver }.to have_enqueued_job(MercadoPago::SyncPaymentJob).with(data_id).on_queue("critical")
      expect(response).to have_http_status(:ok)
    end

    it "acknowledges but ignores notifications that aren't about orders" do
      expect { deliver(payload: body.merge(type: "payment")) }.not_to have_enqueued_job
      expect(response).to have_http_status(:ok)
    end
  end

  context "with a signature that doesn't verify" do
    it "rejects the delivery and enqueues nothing" do
      expect { deliver(signature: "0" * 64) }.not_to have_enqueued_job
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
