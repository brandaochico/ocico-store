# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"

RSpec.describe MelhorEnvio::PackageDimensions do
  let(:product) { create(:product) }
  let(:variant) { create(:variant, product:) }

  def tag_type(name)
    taxonomy = Spree::Taxonomy.find_or_create_by!(name: "Tipo")
    product.taxons << create(:taxon, name:, taxonomy:, parent: taxonomy.root)
  end

  it "uses the variant's own measurements when complete, rounding centimetres up" do
    variant.update!(weight: 0.12, height: 2.2, width: 11, depth: 16)

    expect(described_class.for(variant)).to have_attributes(weight: 0.12, height: 3, width: 11, length: 16)
  end

  it "falls back to the master variant's measurements" do
    product.master.update!(weight: 0.9, height: 10, width: 20, depth: 25)
    variant.update!(weight: 0, height: nil, width: nil, depth: nil)

    expect(described_class.for(variant)).to have_attributes(weight: 0.9, height: 10, width: 20, length: 25)
  end

  it "ignores incomplete measurements and uses the default for the product's Tipo" do
    variant.update!(weight: 0.05, height: nil, width: nil, depth: nil)
    product.master.update!(weight: 0, height: nil, width: nil, depth: nil)
    tag_type("Cartas Avulsas")

    expect(described_class.for(variant)).to eq(described_class::DEFAULTS_BY_TYPE.fetch("Cartas Avulsas"))
  end

  it "quotes a product with no known Tipo as a booster box" do
    variant.update!(weight: 0, height: nil, width: nil, depth: nil)
    product.master.update!(weight: 0, height: nil, width: nil, depth: nil)

    expect(described_class.for(variant)).to eq(described_class::FALLBACK)
  end

  it "has a default for every Tipo the catalog seeds" do
    seeded_types = [ "Booster Box", "Mini Booster Box", "ETB", "Booster Unitário", "Blister",
                     "Caixas Colecionáveis", "Cartas Avulsas" ]

    expect(described_class::DEFAULTS_BY_TYPE.keys).to match_array(seeded_types)
  end
end
