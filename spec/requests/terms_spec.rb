# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"

RSpec.describe "Terms of service", type: :request do
  let!(:store) { create(:store) }

  it "is its own page, in Portuguese" do
    get "/termos-de-servico"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("storefront.terms.title"))
    expect(response.body).to include("Direito de arrependimento")
  end

  it "is linked from the footer" do
    get "/termos-de-servico"

    expect(response.body).to include(%(href="#{terms_path}"))
  end
end
