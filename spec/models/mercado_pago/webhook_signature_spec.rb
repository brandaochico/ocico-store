# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"

RSpec.describe MercadoPago::WebhookSignature do
  let(:secret) { "webhook-secret" }
  let(:data_id) { "ORD01SPEC" }
  let(:request_id) { "bb56a2f1-6aae-46ac-982e-9dcd3581d08e" }
  let(:ts) { "1742505638683" }

  # The manifest format documented by Mercado Pago, spelled out here rather
  # than reusing the implementation's builder.
  def sign(id: data_id, rid: request_id)
    OpenSSL::HMAC.hexdigest("SHA256", secret, "id:#{id};request-id:#{rid};ts:#{ts};")
  end

  def valid?(header, id: data_id, rid: request_id, key: secret)
    described_class.valid?(x_signature: header, x_request_id: rid, data_id: id, secret: key)
  end

  it "accepts a correctly signed notification" do
    expect(valid?("ts=#{ts},v1=#{sign}")).to be(true)
  end

  it "tolerates spaces around the header's parts" do
    expect(valid?("ts=#{ts}, v1=#{sign}")).to be(true)
  end

  it "accepts an id signed in lowercase, per Mercado Pago's older docs" do
    expect(valid?("ts=#{ts},v1=#{sign(id: data_id.downcase)}")).to be(true)
  end

  it "rejects a signature made with another secret" do
    expect(valid?("ts=#{ts},v1=#{sign}", key: "other")).to be(false)
  end

  it "rejects a signature for a different order id" do
    expect(valid?("ts=#{ts},v1=#{sign}", id: "ORD01OTHER")).to be(false)
  end

  it "rejects a malformed or missing header" do
    expect(valid?("v1=#{sign}")).to be(false)
    expect(valid?(nil)).to be(false)
  end

  it "rejects everything when no secret is configured" do
    expect(valid?("ts=#{ts},v1=#{sign}", key: nil)).to be(false)
  end
end
