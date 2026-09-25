# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"

require Rails.root.join("spec/support/solidus_stripe/webhook/event_with_context_factory")

# This job is where every Stripe-driven payment state transition happens, and
# Stripe delivers at least once — so "runs the transition exactly once, even
# under duplicate or concurrent delivery" is the property worth pinning down.
RSpec.describe ProcessStripeWebhookEventJob do
  subject(:process) { described_class.perform_now(payload) }

  let!(:store) { create(:store) }

  let(:payment_method) do
    SolidusStripe::PaymentMethod.create!(
      name: "Stripe",
      preferences: {
        api_key: "sk_test_jobspec",
        publishable_key: "pk_test_jobspec",
        webhook_endpoint_signing_secret: "whsec_jobspec"
      }
    )
  end

  let(:payment) do
    create(
      :payment,
      payment_method: payment_method,
      response_code: "pi_jobspec",
      state: "pending"
    )
  end

  # amount == amount_received keeps the subscriber out of RefundsSynchronizer,
  # which would otherwise call the Stripe API — no spec here talks to Stripe.
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

  let(:payload) { context.solidus_stripe_object.payload.as_json }

  it "publishes the event so solidus_stripe's own subscribers handle it" do
    expect { process }.to change { payment.reload.state }.from("pending").to("completed")
  end

  it "records the delivery and marks it processed" do
    process

    event = StripeWebhookEvent.sole
    expect(event).to have_attributes(
      stripe_event_id: context.data.fetch("id"),
      event_type: "payment_intent.succeeded"
    )
    expect(event).to be_processed
  end

  context "when the same event is delivered twice" do
    it "records it once" do
      process

      expect { described_class.perform_now(payload) }
        .not_to change(StripeWebhookEvent, :count).from(1)
    end

    it "does not run the transition again" do
      process
      payment.reload

      expect { described_class.perform_now(payload) }
        .not_to change { payment.reload.log_entries.count }
    end
  end

  context "when processing raises" do
    before do
      allow(Spree::Bus).to receive(:publish).and_raise("Stripe subscriber blew up")
    end

    it "leaves the event unprocessed so an Active Job retry can pick it up" do
      expect { process }.to raise_error("Stripe subscriber blew up")

      expect(StripeWebhookEvent.sole).not_to be_processed
    end
  end

  describe "claiming an event id" do
    it "returns the existing row instead of failing on the unique index" do
      first = StripeWebhookEvent.claim(stripe_event_id: "evt_dup", event_type: "charge.refunded")
      second = StripeWebhookEvent.claim(stripe_event_id: "evt_dup", event_type: "charge.refunded")

      expect(second).to eq(first)
      expect(StripeWebhookEvent.count).to eq(1)
    end

    it "is guarded by a unique index, not just a validation" do
      StripeWebhookEvent.create!(stripe_event_id: "evt_raw", event_type: "charge.refunded")

      expect {
        StripeWebhookEvent.new(stripe_event_id: "evt_raw", event_type: "charge.refunded").save!(validate: false)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
