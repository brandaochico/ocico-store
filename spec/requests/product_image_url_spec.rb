# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"

# The link a page embeds keeps working long after the page was cached
# (app/overrides/permanent_image_urls.rb).
RSpec.describe "Product image links", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let!(:store) { create(:store) }
  let(:png_path) do
    Rails.root.join("tmp/spec-link-#{Process.pid}.png").tap { Vips::Image.black(400, 600, bands: 4).write_to_file(it.to_s) }
  end
  let(:image) do
    Spree::Image.create!(viewable: create(:variant), attachment: Rack::Test::UploadedFile.new(png_path, "image/png"))
  end

  after { FileUtils.rm_f(png_path) }

  it "still serves the image a day after the link was generated, as a cacheable PNG" do
    url = image.url(:product)

    travel 1.day do
      get url
      follow_redirect! while response.redirect?
    end

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("image/png")
    expect(response.headers["Cache-Control"]).to include("public")
  end
end
