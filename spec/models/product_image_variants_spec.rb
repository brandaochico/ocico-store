# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"

# Product images: always whole — fitted inside a 600x600 box, never cropped —
# transparency kept, and a variant whose file went missing comes back
# (config/initializers/spree.rb, app/overrides/fit_product_image_styles.rb,
# app/overrides/self_healing_image_variants.rb).
RSpec.describe "Product image variants" do
  let!(:store) { create(:store) }

  # A small portrait, fully transparent PNG (2:3, like a card) — the shape of
  # a product photo with its background removed.
  let(:png_path) do
    path = Rails.root.join("tmp/spec-transparent-#{Process.pid}.png")
    Vips::Image.black(200, 300, bands: 4).write_to_file(path.to_s)
    path
  end
  let(:image) do
    Spree::Image.create!(viewable: create(:variant), attachment: Rack::Test::UploadedFile.new(png_path, "image/png"))
  end

  after { FileUtils.rm_f(png_path) }

  def variant_file(style)
    blob = image.attachment.variant(style).image.blob
    Vips::Image.new_from_buffer(blob.download, "")
  end

  it "fits every display size whole inside 600x600: full height, aspect kept, nothing cropped" do
    %i[product large big full].each do |style|
      file = variant_file(style)
      expect([ file.width, file.height ]).to eq([ 400, 600 ]), "#{style} is #{file.width}x#{file.height}"
    end
  end

  it "makes a version fitted inside 1200x1200 for the hover magnifier" do
    file = variant_file(:zoom)

    expect([ file.width, file.height ]).to eq([ 800, 1200 ])
  end

  it "keeps a PNG's transparency" do
    file = variant_file(:product)

    expect(file.has_alpha?).to be(true)
    expect(file.extract_band(3).max).to eq(0) # still fully transparent
  end

  it "fits the thumbnails whole inside smaller boxes" do
    expect(variant_file(:small).then { [ it.width, it.height ] }).to eq([ 200, 300 ])
    expect(variant_file(:mini).then { [ it.width, it.height ] }).to eq([ 80, 120 ])
  end

  # Signed service URLs expire in minutes and end up inside cached HTML.
  it "links to the permanent proxy route, never to an expiring signed URL" do
    url = image.url(:product)

    expect(url).to start_with("/rails/active_storage/representations/proxy/")
    expect(url).not_to include("/disk/")
  end

  it "regenerates a variant whose file has gone missing instead of serving a dead link" do
    blob = image.attachment.variant(:product).image.blob
    blob.service.delete(blob.key)

    image.attachment.variant(:product)

    regenerated = image.attachment.variant(:product).image.blob
    expect(regenerated.service.exist?(regenerated.key)).to be(true)
  end
end
