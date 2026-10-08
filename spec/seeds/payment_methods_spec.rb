# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"

# Money logic gets the strictest coverage in this project, and the seed is what
# decides how every environment's Stripe payment method is configured — most
# importantly that it authorizes rather than captures, and that no secret is
# ever written to the database.
RSpec.describe "db/seeds/payment_methods.rb" do
  subject(:run_seed) { load Rails.root.join("db/seeds/payment_methods.rb") }

  let(:preference_source) { "solidus_stripe_env_credentials" }

  # The real registration happens in config/initializers/solidus_stripe.rb, and
  # only when credentials are present — which they aren't in the test env. This
  # is the same static preference, registered per example.
  def registered_preferences
    Spree::Config.static_model_preferences.for_class(SolidusStripe::PaymentMethod)
  end

  around do |example|
    original = registered_preferences.dup
    example.run
    registered_preferences.replace(original)
  end

  context "when no Stripe credentials are configured" do
    before { registered_preferences.clear }

    it "creates no payment method rather than one that can't transact" do
      expect { run_seed }.not_to change(SolidusStripe::PaymentMethod, :count).from(0)
    end
  end

  context "when Stripe credentials are configured" do
    before do
      registered_preferences.clear

      Spree::Config.static_model_preferences.add(
        "SolidusStripe::PaymentMethod",
        preference_source,
        api_key: "sk_test_seedspec",
        publishable_key: "pk_test_seedspec",
        test_mode: true,
        webhook_endpoint_signing_secret: "whsec_seedspec"
      )
    end

    it "creates a single Stripe payment method available to both storefront and admin" do
      expect { run_seed }.to change(SolidusStripe::PaymentMethod, :count).by(1)

      payment_method = SolidusStripe::PaymentMethod.sole
      expect(payment_method).to have_attributes(
        active: true,
        available_to_users: true,
        available_to_admin: true
      )
    end

    it "authorizes at checkout instead of capturing immediately" do
      run_seed

      expect(SolidusStripe::PaymentMethod.sole.auto_capture?).to be(false)
    end

    it "reads its credentials from the static preference" do
      run_seed

      payment_method = SolidusStripe::PaymentMethod.sole
      expect(payment_method.preference_source).to eq(preference_source)
      expect(payment_method.preferred_api_key).to eq("sk_test_seedspec")
      expect(payment_method.preferred_publishable_key).to eq("pk_test_seedspec")
      expect(payment_method.preferred_webhook_endpoint_signing_secret).to eq("whsec_seedspec")
    end

    it "persists no secret on the record itself" do
      run_seed

      persisted = SolidusStripe::PaymentMethod.sole.read_attribute(:preferences).to_s
      expect(persisted).not_to include("sk_test_seedspec", "whsec_seedspec")
    end

    it "renders through the storefront's stripe partials" do
      run_seed

      expect(SolidusStripe::PaymentMethod.sole.partial_name).to eq("stripe")
    end

    it "is idempotent" do
      run_seed

      expect { run_seed }.not_to change(SolidusStripe::PaymentMethod, :count).from(1)
    end
  end

  describe "Pix and Boleto (Mercado Pago)" do
    let(:mp_preference_source) { "mercado_pago_env_credentials" }
    let(:mp_classes) { [ MercadoPago::PixPaymentMethod, MercadoPago::BoletoPaymentMethod ] }

    def mp_preferences(klass)
      Spree::Config.static_model_preferences.for_class(klass)
    end

    around do |example|
      originals = mp_classes.to_h { |klass| [ klass, mp_preferences(klass).dup ] }
      example.run
      originals.each { |klass, original| mp_preferences(klass).replace(original) }
    end

    context "when no Mercado Pago credentials are configured" do
      before { mp_classes.each { |klass| mp_preferences(klass).clear } }

      it "creates neither" do
        expect { run_seed }.not_to change(MercadoPago::PaymentMethod, :count).from(0)
      end
    end

    context "when Mercado Pago credentials are configured" do
      before do
        mp_classes.each do |klass|
          mp_preferences(klass).clear
          Spree::Config.static_model_preferences.add(
            klass.name, mp_preference_source, access_token: "APP_USR-seedspec", public_key: "APP_USR-pk"
          )
        end
      end

      it "creates Pix and Boleto for the storefront only" do
        run_seed

        expect(MercadoPago::PaymentMethod.order(:name).map { |pm| [ pm.class, pm.name ] }).to eq(
          [ [ MercadoPago::BoletoPaymentMethod, "Boleto" ], [ MercadoPago::PixPaymentMethod, "Pix" ] ]
        )
        expect(MercadoPago::PaymentMethod.all).to all(
          have_attributes(active: true, available_to_users: true, available_to_admin: false)
        )
      end

      it "lists Pix first, so the payment step pre-selects it" do
        create(:check_payment_method)

        run_seed

        expect(Spree::PaymentMethod.order(:position).first(2).map(&:name)).to eq(%w[Pix Boleto])
      end

      it "never completes a payment before the customer pays" do
        run_seed

        expect(MercadoPago::PaymentMethod.all.map(&:auto_capture?)).to all(be(false))
      end

      it "reads the access token from the static preference, persisting no secret" do
        run_seed

        pix = MercadoPago::PixPaymentMethod.sole
        expect(pix.preferred_access_token).to eq("APP_USR-seedspec")
        expect(pix.read_attribute(:preferences).to_s).not_to include("APP_USR-seedspec")
      end

      it "is idempotent" do
        run_seed

        expect { run_seed }.not_to change(MercadoPago::PaymentMethod, :count).from(2)
      end
    end
  end
end
