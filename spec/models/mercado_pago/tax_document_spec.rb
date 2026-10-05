# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"

RSpec.describe MercadoPago::TaxDocument do
  describe ".valid?" do
    it "accepts a CPF with correct check digits, formatted or not" do
      expect(described_class.valid?("191.191.191-00")).to be(true)
      expect(described_class.valid?("52998224725")).to be(true)
    end

    it "accepts a CNPJ with correct check digits" do
      expect(described_class.valid?("11.222.333/0001-81")).to be(true)
    end

    it "rejects a wrong check digit" do
      expect(described_class.valid?("52998224724")).to be(false)
      expect(described_class.valid?("11222333000182")).to be(false)
    end

    it "rejects repeated digits, which pass the checksum but aren't real documents" do
      expect(described_class.valid?("11111111111")).to be(false)
      expect(described_class.valid?("00000000000000")).to be(false)
    end

    it "rejects any other length" do
      expect(described_class.valid?("1234")).to be(false)
      expect(described_class.valid?("")).to be(false)
    end
  end

  describe ".type" do
    it "tells CPF from CNPJ by length" do
      expect(described_class.type("529.982.247-25")).to eq("CPF")
      expect(described_class.type("11.222.333/0001-81")).to eq("CNPJ")
      expect(described_class.type("123")).to be_nil
    end
  end
end
