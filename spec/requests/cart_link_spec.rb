# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"

# top_bar_controller.js fetches this on every page load and writes the response
# body straight into the header with innerHTML. That makes a 500 here
# especially nasty: the Rails error page's own <style> block gets injected into
# the document and restyles the whole storefront, so the visible symptom is
# "the page lost its CSS" rather than anything that points at this action.
RSpec.describe "Cart link", type: :request do
  let!(:store) { create(:store) }

  it "renders the cart link" do
    get cart_link_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("cart")
  end

  it "answers a revalidation with 304 instead of raising DoubleRenderError" do
    get cart_link_path
    etag = response.headers["ETag"]
    expect(etag).to be_present

    get cart_link_path, headers: { "HTTP_IF_NONE_MATCH" => etag }

    expect(response).to have_http_status(:not_modified)
  end

  it "renders again when the cached copy is stale" do
    get cart_link_path, headers: { "HTTP_IF_NONE_MATCH" => 'W/"something-else"' }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("cart")
  end
end
