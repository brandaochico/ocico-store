# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"

# app/views/products/_product_gallery.html.erb
RSpec.describe "Product page gallery", type: :request do
  let!(:store) { create(:store) }
  let(:product) { create(:product) }
  let(:png_path) do
    Rails.root.join("tmp/spec-gallery-#{Process.pid}.png").tap { Vips::Image.black(400, 600, bands: 4).write_to_file(it.to_s) }
  end

  after { FileUtils.rm_f(png_path) }

  def add_image(alt)
    Spree::Image.create!(viewable: product.master, alt:, attachment: Rack::Test::UploadedFile.new(png_path, "image/png"))
  end

  def thumbnails = Nokogiri::HTML(response.body).css("[data-product-gallery-target='thumbnail']")

  it "shows a single image once, without a thumbnail strip duplicating it" do
    add_image("Frente")

    get product_path(product)

    expect(thumbnails).to be_empty
    expect(Nokogiri::HTML(response.body).css("[data-product-gallery-target='main']").size).to eq(1)
  end

  it "lists every image as a thumbnail that knows its display and zoom images" do
    add_image("Frente")
    add_image("Verso")

    get product_path(product)

    expect(thumbnails.size).to eq(2)
    expect(thumbnails.map { it["data-alt"] }).to eq([ "Frente", "Verso" ])
    expect(thumbnails.first["aria-current"]).to eq("true")
    thumbnails.each do |thumbnail|
      expect(thumbnail["data-url"]).to start_with("/rails/active_storage/representations/proxy/")
      expect(thumbnail["data-zoom-url"]).to start_with("/rails/active_storage/representations/proxy/")
    end
  end
end
