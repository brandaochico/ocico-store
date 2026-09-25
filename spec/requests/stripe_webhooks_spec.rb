# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"

require Rails.root.join("spec/support/solidus_stripe/webhook/event_with_context_factory")
require Rails.root.join("spec/support/solidus_stripe/webhook/request_helper")

# Upstream's controller does the payment state transition inline, while Stripe
# waits on the response. These specs pin the behaviour our override replaces it
# with: verify in the request, work in the background.
RSpec.describe "Stripe webhooks", type: :request do
  include SolidusStripe::Webhook::RequestHelper

  let!(:store) { create(:store) }

  let(:payment_method) do
    SolidusStripe::PaymentMethod.create!(
      name: "Stripe",
      preferences: {
        api_key: "sk_test_webhookspec",
        publishable_key: "pk_test_webhookspec",
        webhook_endpoint_signing_secret: "whsec_webhookspec"
      }
    )
  end

  let(:payment) do
    create(
      :payment,
      payment_method: payment_method,
      response_code: "pi_webhookspec",
      state: "pending"
    )
  end

  let(:context) do
    SolidusStripe::Webhook::EventWithContextFactory.from_object(
      object: {
        "id" => payment.response_code,
        "object" => "payment_intent",
        "amount" => 1_000,
        "amount_received" => 1_000,
        "currency" => "brl"
      },
      type: "payment_intent.succeeded",
      payment_method: payment_method
    )
  end

  context "with a valid signature" do
    it "acknowledges the delivery" do
      webhook_request(context)

      expect(response).to have_http_status(:ok)
    end

    it "enqueues the event for background processing" do
      expect { webhook_request(context) }
        .to have_enqueued_job(ProcessStripeWebhookEventJob)
        .on_queue("critical")
    end

    it "does not transition the payment inside the request" do
      payment # created before the request, so we're not just seeing creation order

      expect { webhook_request(context) }.not_to change { payment.reload.state }.from("pending")
    end
  end

  context "with a signature that doesn't verify" do
    it "rejects the delivery and enqueues nothing" do
      expect {
        post "/solidus_stripe/#{context.slug}/webhooks",
          params: context.json,
          headers: {
            SolidusStripe::WebhooksController::SIGNATURE_HEADER => "t=1,v1=not_a_real_signature",
            "CONTENT_TYPE" => "application/json"
          }
      }.not_to have_enqueued_job(ProcessStripeWebhookEventJob)

      expect(response).to have_http_status(:bad_request)
    end
  end

  context "when the signature is older than Stripe's tolerance" do
    it "rejects the delivery" do
      webhook_request(context, timestamp: 1.day.ago)

      expect(response).to have_http_status(:bad_request)
    end
  end
end
