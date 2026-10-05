# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"

RSpec.describe OcicoAdmin::AddressFormComponent, type: :component do
  it "is what solidus_admin renders as its address form" do
    expect(SolidusAdmin::Config.components["ui/forms/address"]).to eq(described_class)
  end

  it "adds street number and neighbourhood to the stock fields" do
    render_inline(described_class.new(address: build(:address), name: "order[bill_address_attributes]"))

    expect(page).to have_field("order[bill_address_attributes][address1]")
    expect(page).to have_field("order[bill_address_attributes][street_number]")
    expect(page).to have_field("order[bill_address_attributes][neighborhood]")
    expect(page).to have_field("order[bill_address_attributes][zipcode]")
  end

  it "keeps the stock component's Stimulus controller, which reloads states" do
    render_inline(described_class.new(address: build(:address), name: "order[bill_address_attributes]"))

    expect(page).to have_css('fieldset[data-controller="ui--forms--address"]')
  end
end
