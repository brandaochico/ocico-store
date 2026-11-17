# frozen_string_literal: true

require "rails_helper"

RSpec.describe "request log parameter filtering" do
  subject(:filter) { ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters) }

  it "hides the Boleto payer's CPF/CNPJ" do
    params = { "payment_source" => { "3" => { "payer_document" => "191.000.000-00" } } }

    expect(filter.filter(params).dig("payment_source", "3", "payer_document")).to eq("[FILTERED]")
  end

  it "hides fields named after the documents directly" do
    expect(filter.filter("cpf" => "19100000000", "cnpj" => "70184624000191"))
      .to eq("cpf" => "[FILTERED]", "cnpj" => "[FILTERED]")
  end
end
