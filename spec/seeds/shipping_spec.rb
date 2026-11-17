# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"

RSpec.describe "db/seeds/shipping.rb" do
  subject(:run_seed) { load Rails.root.join("db/seeds/shipping.rb") }

  before { create(:country, iso: "BR", name: "Brazil", states_required: true) unless Spree::Country.exists?(iso: "BR") }

  def melhor_envio_services
    Spree::ShippingMethod.all.select { |method| method.calculator.is_a?(MelhorEnvio::ShippingCalculator) }
      .to_h { |method| [ method.calculator.preferred_service_id, method.name ] }
  end

  it "creates one shipping method per Melhor Envio service, in the Brazil zone" do
    run_seed

    expect(melhor_envio_services).to eq(
      1 => "Correios PAC", 2 => "Correios SEDEX", 3 => "Jadlog .Package", 17 => "Correios Mini Envios"
    )
    expect(Spree::ShippingMethod.all.flat_map(&:zones).map(&:name).uniq).to eq([ "Brasil" ])
  end

  it "creates the fallback flat rate" do
    run_seed

    fallback = Spree::ShippingMethod.find_by!(name: "Entrega padrão")
    expect(fallback.calculator).to be_a(MelhorEnvio::FallbackCalculator)
    expect(fallback.calculator.preferences).to include(amount: 20, currency: "BRL")
  end

  it "converts the provisional flat rate into the fallback rather than leaving both" do
    provisional = create(:shipping_method, name: "Frete fixo (provisório)")

    run_seed

    expect(provisional.reload.name).to eq("Entrega padrão")
    expect(provisional.calculator).to be_a(MelhorEnvio::FallbackCalculator)
    expect(Spree::ShippingMethod.where(name: [ "Frete fixo (provisório)", "Entrega padrão" ]).count).to eq(1)
  end

  describe "the dispatch origin Melhor Envio quotes from" do
    let!(:stock_location) { create(:stock_location, zipcode: nil, city: nil) }

    it "sets the stock location's CEP to Canoas/RS when it has none" do
      run_seed

      expect(stock_location.reload).to have_attributes(zipcode: "92020-300", city: "Canoas")
      expect(stock_location.country.iso).to eq("BR")
    end

    it "never overwrites a CEP entered in the admin" do
      stock_location.update!(zipcode: "01310-100")

      run_seed

      expect(stock_location.reload.zipcode).to eq("01310-100")
    end
  end

  it "is idempotent, even after a method is renamed in the admin" do
    run_seed
    Spree::ShippingMethod.find_by!(name: "Correios PAC").update!(name: "PAC")

    expect { run_seed }.not_to change(Spree::ShippingMethod, :count)
  end
end
