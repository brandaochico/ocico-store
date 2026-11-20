# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"

# Product images: always a 600x600 square, transparency kept, and a variant
# whose file went missing comes back (config/initializers/spree.rb,
# app/overrides/self_healing_image_variants.rb).
RSpec.describe "Product image variants" do
  let!(:store) { create(:store) }

  # A portrait, fully transparent PNG — the shape of a product photo with its
  # background removed.
  let(:png_path) do
    path = Rails.root.join("tmp/spec-transparent-#{Process.pid}.png")
    Vips::Image.black(400, 600, bands: 4).write_to_file(path.to_s)
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

  it "resizes and crops every display size to a 600x600 square" do
    %i[product large big full].each do |style|
      file = variant_file(style)
      expect([ file.width, file.height ]).to eq([ 600, 600 ]), "#{style} is #{file.width}x#{file.height}"
    end
  end

  it "keeps a PNG's transparency" do
    file = variant_file(:product)

    expect(file.has_alpha?).to be(true)
    expect(file.extract_band(3).max).to eq(0) # still fully transparent
  end

  it "makes the thumbnails smaller squares of the same crop" do
    expect(variant_file(:small).then { [ it.width, it.height ] }).to eq([ 300, 300 ])
    expect(variant_file(:mini).then { [ it.width, it.height ] }).to eq([ 120, 120 ])
  end

  it "regenerates a variant whose file has gone missing instead of serving a dead link" do
    blob = image.attachment.variant(:product).image.blob
    blob.service.delete(blob.key)

    image.attachment.variant(:product)

    regenerated = image.attachment.variant(:product).image.blob
    expect(regenerated.service.exist?(regenerated.key)).to be(true)
  end
end
