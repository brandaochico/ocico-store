# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"

RSpec.describe BrazilianAddress do
  def brazilian_address(**attributes)
    build(:address, country_iso_code: "BR", state_code: "SP", address1: "Av. Paulista",
                    street_number: "1000", neighborhood: "Bela Vista", zipcode: "01310-100", **attributes)
  end

  it "accepts a complete Brazilian address" do
    expect(brazilian_address).to be_valid
  end

  it "requires the street number and the neighbourhood" do
    address = brazilian_address(street_number: " ", neighborhood: nil)

    expect(address).not_to be_valid
    expect(address.errors.attribute_names).to include(:street_number, :neighborhood)
  end

  it "doesn't require a complement" do
    expect(brazilian_address(address2: nil)).to be_valid
  end

  it "stores the CEP as 00000-000 however it was typed" do
    address = brazilian_address(zipcode: "01310100")
    address.valid?

    expect(address.zipcode).to eq("01310-100")
  end

  it "rejects a CEP that isn't 8 digits" do
    address = brazilian_address(zipcode: "1310-100")

    expect(address).not_to be_valid
    expect(address.errors.details[:zipcode]).to include(error: :invalid)
  end

  it "reports each problem once" do
    address = brazilian_address(street_number: nil)
    address.valid?

    expect(address.errors.details[:street_number].size).to eq(1)
  end

  it "leaves addresses in other countries to Solidus' own rules" do
    expect(build(:address, street_number: nil, neighborhood: nil, zipcode: "10001")).to be_valid
  end

  it "treats a different number or neighbourhood as a different address" do
    expect(brazilian_address).not_to eq(brazilian_address(street_number: "1001"))
  end
end
