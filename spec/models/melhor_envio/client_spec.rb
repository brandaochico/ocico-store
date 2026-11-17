# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("spec/support/melhor_envio_api")

RSpec.describe MelhorEnvio::Client do
  subject(:client) { described_class.from_config(MelhorEnvioApi.config) }

  let(:products) do
    [ { id: "1", width: 11, height: 2, length: 16, weight: 0.05, insurance_value: 79.9, quantity: 2 } ]
  end

  it "posts the quote with the token, the User-Agent Melhor Envio requires and digits-only CEPs" do
    request = stub_request(:post, MelhorEnvioApi::SANDBOX_URL)
      .with(
        headers: {
          "Authorization" => "Bearer me-spec-token",
          "Accept" => "application/json",
          "User-Agent" => "ocico store (dev@example.com)"
        },
        body: { from: { postal_code: "01310100" }, to: { postal_code: "20040002" }, products: products }.to_json
      )
      .to_return(MelhorEnvioApi.json(MelhorEnvioApi.quote_response))

    services = client.calculate(from: "01310-100", to: "20040-002", products:)

    expect(request).to have_been_requested
    expect(services.map { |service| service["id"] }).to eq([ 1, 2, 3, 17 ])
  end

  it "talks to production when sandbox is off" do
    request = stub_request(:post, MelhorEnvioApi::PRODUCTION_URL).to_return(MelhorEnvioApi.json([]))

    described_class.from_config(MelhorEnvioApi.config(sandbox: false)).calculate(from: "1", to: "2", products:)

    expect(request).to have_been_requested
  end

  it "raises with Melhor Envio's message on an error response" do
    stub_request(:post, MelhorEnvioApi::SANDBOX_URL)
      .to_return(MelhorEnvioApi.json({ "message" => "The given data was invalid." }, status: 422))

    expect { client.calculate(from: "1", to: "2", products:) }
      .to raise_error(described_class::Error, "The given data was invalid.") { |error| expect(error.status).to eq(422) }
  end

  it "turns a timeout into its own error, never a raw network exception" do
    stub_request(:post, MelhorEnvioApi::SANDBOX_URL).to_timeout

    expect { client.calculate(from: "1", to: "2", products:) }.to raise_error(described_class::Error, /unreachable/)
  end
end
