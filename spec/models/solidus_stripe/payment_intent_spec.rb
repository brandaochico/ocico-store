# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"

# Live Stripe accounts created from late 2026 on reject `payment_method_types`
# next to a customer and a PaymentMethod — see
# app/overrides/stripe_intent_without_payment_method_types.rb.
RSpec.describe SolidusStripe::PaymentIntent do
  let!(:store) { create(:store) }

  let(:payment_method) do
    SolidusStripe::PaymentMethod.create!(
      name: "Stripe",
      auto_capture: false,
      preferences: {
        api_key: "sk_test_intentspec",
        publishable_key: "pk_test_intentspec",
        webhook_endpoint_signing_secret: "whsec_intentspec"
      }
    )
  end
  let(:order) { create(:order_with_line_items) }
  let(:source) { SolidusStripe::PaymentSource.create!(payment_method:, stripe_payment_method_id: "pm_intentspec") }
  let(:payment) { create(:payment, order:, payment_method:, source:, amount: order.total) }

  before do
    allow(SolidusStripe::Customer).to receive(:retrieve_or_create_stripe_customer_id).and_return("cus_intentspec")
    # prepare_for_payment re-reads the intent to attach its id to the payment.
    allow(Stripe::PaymentIntent).to receive(:retrieve) { |id| Stripe::PaymentIntent.construct_from(id:) }
  end

  it "creates the intent without payment_method_types" do
    allow(Stripe::PaymentIntent).to receive(:create).and_return(Stripe::PaymentIntent.construct_from(id: "pi_new"))

    described_class.prepare_for_payment(payment)

    expect(Stripe::PaymentIntent).to have_received(:create) do |params|
      expect(params).to include(customer: "cus_intentspec", payment_method: "pm_intentspec", capture_method: "manual")
      expect(params).not_to have_key(:payment_method_types)
    end
  end

  it "updates a reusable intent without payment_method_types" do
    described_class.create!(order:, payment_method:, stripe_intent_id: "pi_existing")
    allow_any_instance_of(described_class).to receive(:usable?).and_return(true) # rubocop:disable RSpec/AnyInstance
    allow(Stripe::PaymentIntent).to receive(:update)

    described_class.prepare_for_payment(payment)

    expect(Stripe::PaymentIntent).to have_received(:update).with("pi_existing", { payment_method: "pm_intentspec" })
  end
end
