# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"

RSpec.describe MercadoPago::PaymentSource do
  let(:pix) { MercadoPago::PixPaymentMethod.create!(name: "Pix") }
  let(:boleto) { MercadoPago::BoletoPaymentMethod.create!(name: "Boleto") }

  it "stores the CPF/CNPJ as digits only" do
    source = described_class.create!(payment_method: boleto, payer_document: "529.982.247-25")

    expect(source.payer_document).to eq("52998224725")
  end

  context "for Boleto" do
    it "requires a CPF/CNPJ" do
      source = described_class.new(payment_method: boleto, payer_document: "")

      expect(source).not_to be_valid
      expect(source.errors[:payer_document]).to be_present
    end

    it "rejects an invalid CPF/CNPJ" do
      source = described_class.new(payment_method: boleto, payer_document: "123.456.789-00")

      expect(source).not_to be_valid
    end
  end

  context "for Pix" do
    it "doesn't require a CPF/CNPJ" do
      expect(described_class.new(payment_method: pix, payer_document: "")).to be_valid
    end

    it "still rejects one that is given but invalid" do
      expect(described_class.new(payment_method: pix, payer_document: "11111111111")).not_to be_valid
    end
  end

  it "offers no capture action — the customer pays, nothing is captured" do
    expect(described_class.new.actions).to eq(%w[void credit])
  end
end
