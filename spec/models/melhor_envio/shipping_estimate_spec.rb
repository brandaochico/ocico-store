# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"
require Rails.root.join("spec/support/melhor_envio_api")

# The whole freight path as checkout runs it: Solidus's estimator asking each
# shipping method's calculator, against a stubbed Melhor Envio.
RSpec.describe "Melhor Envio shipping estimates" do
  include ActiveSupport::Testing::TimeHelpers

  let!(:store) { create(:store) }
  let(:order) { create(:order_with_line_items, line_items_price: 79.9) }
  let(:shipment) { order.shipments.first }
  let(:package) { shipment.to_package }
  let(:category) { order.line_items.first.product.shipping_category }
  let(:zone) { create(:zone, countries: [ order.ship_address.country ]) }

  let(:melhor_envio_config) { MelhorEnvioApi.config }

  def melhor_envio_method(name, service_id)
    create(:shipping_method, name:, zones: [ zone ], shipping_categories: [ category ],
           calculator: MelhorEnvio::ShippingCalculator.new(preferred_service_id: service_id))
  end

  let!(:pac) { melhor_envio_method("Correios PAC", 1) }
  let!(:sedex) { melhor_envio_method("Correios SEDEX", 2) }
  let!(:jadlog) { melhor_envio_method("Jadlog .Package", 3) }
  let!(:mini_envios) { melhor_envio_method("Correios Mini Envios", 17) }
  let!(:fallback) do
    create(:shipping_method, name: "Entrega padrão", zones: [ zone ], shipping_categories: [ category ],
           calculator: MelhorEnvio::FallbackCalculator.new(preferred_amount: 20, preferred_currency: "USD"))
  end

  let(:rates) { Spree::Stock::Estimator.new.shipping_rates(package) }
  let(:offered) { rates.to_h { |rate| [ rate.shipping_method.name, rate.cost ] } }

  before do
    MelhorEnvio::Quote.cache.clear
    # Only this store's methods: drop the flat rate the order factory brings.
    Spree::ShippingMethod.where.not(id: [ pac, sedex, jadlog, mini_envios, fallback ].map(&:id)).find_each(&:destroy)
    package.stock_location.update!(zipcode: "01310-100")
    # The suite runs in USD (see solidus_starter_frontend_spec_helper); the
    # calculators must match the order's currency to be considered at all.
    Spree::ShippingMethod.find_each { |method| method.calculator.update!(preferred_currency: order.currency) }
    allow(Rails.application.config.x).to receive(:melhor_envio).and_return(melhor_envio_config)
  end

  context "when Melhor Envio quotes" do
    let!(:quote_request) do
      stub_request(:post, MelhorEnvioApi::SANDBOX_URL).to_return(MelhorEnvioApi.json(MelhorEnvioApi.quote_response))
    end

    it "offers each carrier that can take the shipment at Melhor Envio's price, and hides the rest" do
      expect(offered).to eq("Correios PAC" => 25.40.to_d, "Correios SEDEX" => 41.90.to_d)
    end

    it "pre-selects the cheapest" do
      expect(rates.find(&:selected).shipping_method).to eq(pac)
    end

    it "keeps each rate's delivery time" do
      sedex_rate = rates.find { |rate| rate.shipping_method == sedex }

      expect([ sedex_rate.min_delivery_days, sedex_rate.max_delivery_days ]).to eq([ 1, 2 ])
    end

    it "reuses a priced quote for later estimates of the same cart" do
      rates
      travel(10.minutes) { Spree::Stock::Estimator.new.shipping_rates(package) }

      expect(quote_request).to have_been_requested.once
    end

    it "asks Melhor Envio once for all four carriers" do
      rates

      expect(quote_request).to have_been_requested.once
    end

    it "quotes from the stock location's CEP to the shipping CEP, with each item's price as declared value" do
      rates

      expect(
        a_request(:post, MelhorEnvioApi::SANDBOX_URL).with { |request|
          body = JSON.parse(request.body)
          body["from"]["postal_code"] == "01310100" &&
            body["to"]["postal_code"] == order.ship_address.zipcode.gsub(/\D/, "") &&
            body["products"].map { |product| product["insurance_value"] }.uniq == [ 79.9 ]
        }
      ).to have_been_made
    end

    it "doesn't offer the fallback flat rate" do
      expect(offered).not_to have_key("Entrega padrão")
    end

    context "and no carrier serves the destination" do
      let!(:quote_request) do
        stub_request(:post, MelhorEnvioApi::SANDBOX_URL)
          .to_return(MelhorEnvioApi.json([ MelhorEnvioApi.unavailable(1, "PAC"), MelhorEnvioApi.unavailable(2, "SEDEX") ]))
      end

      it "offers nothing rather than a flat rate for a route nobody delivers to" do
        expect(rates).to be_empty
      end

      # "No carrier" can be a carrier-side outage rather than an unserved
      # route: it mustn't dead-end checkout for that CEP for half an hour.
      it "asks again after a minute instead of caching the empty quote for half an hour" do
        rates
        travel(2.minutes) { Spree::Stock::Estimator.new.shipping_rates(package) }

        expect(quote_request).to have_been_requested.twice
      end
    end
  end

  # Freight must never turn the delivery step into a 500.
  context "when Melhor Envio answers something unusable" do
    {
      "an HTTP 500" => -> { { status: 500, body: "" } },
      "a 200 with an error object instead of a list" => -> { MelhorEnvioApi.json({ "message" => "Unauthenticated." }) },
      "a 200 with a malformed price" => -> { MelhorEnvioApi.json([ MelhorEnvioApi.service(1, "PAC", price: "n/d", min: 5, max: 7) ]) }
    }.each do |description, response|
      it "falls back to the flat rate on #{description}" do
        stub_request(:post, MelhorEnvioApi::SANDBOX_URL).to_return(instance_exec(&response))

        expect(offered).to eq("Entrega padrão" => 20.to_d)
      end
    end

    it "falls back to the flat rate when the connection drops mid-response" do
      stub_request(:post, MelhorEnvioApi::SANDBOX_URL).to_raise(EOFError)

      expect(offered).to eq("Entrega padrão" => 20.to_d)
    end
  end

  context "when Melhor Envio is down" do
    let!(:quote_request) { stub_request(:post, MelhorEnvioApi::SANDBOX_URL).to_timeout }

    it "offers only the fallback flat rate, so checkout can still go on" do
      expect(offered).to eq("Entrega padrão" => 20.to_d)
    end

    it "doesn't retry once per carrier" do
      rates

      expect(quote_request).to have_been_requested.once
    end
  end

  context "when the stock location has no CEP" do
    before { package.stock_location.update!(zipcode: nil) }

    it "falls back to the flat rate without calling Melhor Envio" do
      expect(offered).to eq("Entrega padrão" => 20.to_d)
      expect(a_request(:post, MelhorEnvioApi::SANDBOX_URL)).not_to have_been_made
    end
  end

  context "without a Melhor Envio token" do
    let(:melhor_envio_config) { MelhorEnvioApi.config(token: nil) }

    it "falls back to the flat rate without calling Melhor Envio" do
      expect(offered).to eq("Entrega padrão" => 20.to_d)
      expect(a_request(:post, MelhorEnvioApi::SANDBOX_URL)).not_to have_been_made
    end
  end
end
