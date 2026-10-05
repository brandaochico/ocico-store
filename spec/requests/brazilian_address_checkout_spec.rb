# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"

RSpec.describe "Checkout with a Brazilian address", type: :request, with_signed_in_user: true do
  let(:user) { order.user }
  let(:order) { create(:order_with_line_items, state: "address", bill_address: nil, ship_address: nil) }
  let(:brazil) { create(:country, iso: "BR") }
  let(:sao_paulo) { create(:state, country: brazil, state_code: "SP") }

  before do
    zone = create(:zone, name: "Brasil", countries: [ brazil ])
    order.shipments.first&.shipping_method&.update!(zones: [ zone ])
    create(:shipping_method, zones: [ zone ])
  end

  def address_params(**overrides)
    {
      name: "Ana Maria Silva", address1: "Av. Paulista", street_number: "1000", address2: "Apto 5",
      neighborhood: "Bela Vista", city: "São Paulo", zipcode: "01310100", phone: "11999999999",
      country_id: brazil.id, state_id: sao_paulo.id
    }.merge(overrides)
  end

  it "asks for CEP, number and neighbourhood, wired to the CEP lookup" do
    get checkout_state_path("address")

    expect(response.body).to include(
      'data-controller="address-lookup"',
      "order[bill_address_attributes][street_number]",
      "order[bill_address_attributes][neighborhood]",
      "Número", "Bairro", "Complemento"
    )
  end

  it "saves the number and neighbourhood and moves on to delivery" do
    patch update_checkout_path(state: "address"),
      params: { order: { bill_address_attributes: address_params, use_billing: "1" } }

    order.reload
    expect(order.state).to eq("delivery")
    expect(order.bill_address).to have_attributes(street_number: "1000", neighborhood: "Bela Vista", zipcode: "01310-100")
    expect(order.ship_address).to have_attributes(street_number: "1000", neighborhood: "Bela Vista")
  end

  it "stays on the address step without a street number" do
    patch update_checkout_path(state: "address"),
      params: { order: { bill_address_attributes: address_params(street_number: ""), use_billing: "1" } }

    expect(order.reload.state).to eq("address")
    expect(response.body).to include("Número (endereço de cobrança) não pode ficar em branco")
  end
end
