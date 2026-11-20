# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"

# /products: reachable from the menu, always alphabetical (ProductsController).
RSpec.describe "All products page", type: :request do
  let!(:store) { create(:store) }
  let(:tipo) { create(:taxonomy, name: "Tipo") }
  let!(:booster_box) { create(:taxon, name: "Booster Box", taxonomy: tipo, parent: tipo.root) }

  before do
    # Created out of order, with accents and mixed case, on purpose.
    %w[zebra Énergie abacaxi Banana energia].each_with_index do |name, i|
      create(:product, name:, available_on: (i + 1).days.ago).tap { it.taxons << booster_box }
    end
  end

  def names = assigns(:products).map(&:name)

  it "lists products in Portuguese alphabetical order, ignoring case and accents" do
    get products_path

    expect(names).to eq(%w[abacaxi Banana energia Énergie zebra])
  end

  it "keeps the order when searching" do
    get products_path(keywords: "e")

    expect(names).to eq(names.sort_by { I18n.transliterate(it).downcase })
  end

  it "keeps the order when filtered by a category" do
    get products_path(taxon: booster_box.id)

    expect(response).to have_http_status(:ok)
    expect(names).to eq(%w[abacaxi Banana energia Énergie zebra])
  end

  it "pages through the list in the same order" do
    stub_spree_preferences(products_per_page: 2)

    get products_path(page: 2)

    expect(response).to have_http_status(:ok)
    expect(names).to eq(%w[energia Énergie])
    expect(assigns(:products).total_pages).to eq(3)
  end

  it "is linked from the Produtos menu, below the product types" do
    get root_path

    menu = Nokogiri::HTML(response.body)
    link = menu.css("a[href='#{products_path}']").find { it.text.include?("Ver todos os produtos...") }
    expect(link).to be_present
  end
end
