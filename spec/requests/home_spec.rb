# frozen_string_literal: true

require 'solidus_starter_frontend_spec_helper'

# Each home block picks its products on purpose (HomeController).
RSpec.describe 'Home page', type: :request do
  let!(:store) { create(:store) }
  let(:tipo) { create(:taxonomy, name: "Tipo") }
  let!(:singles) { create(:taxon, name: "Cartas Avulsas", taxonomy: tipo, parent: tipo.root) }

  def product(name, days_ago:, featured: false, single: false)
    create(:product, name:, available_on: days_ago.days.ago, featured:).tap do |p|
      p.taxons << singles if single
    end
  end

  def names(block) = assigns(block).map(&:name)

  it "renders the storefront layout" do
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response).to render_template(layout: 'layouts/storefront')
  end

  it "features only the products marked in the admin, most recently edited first, at most four" do
    product("Comum", days_ago: 1)
    older = product("Destaque antigo", days_ago: 9, featured: true)
    product("Destaque novo", days_ago: 9, featured: true)
    older.touch
    3.times { |i| product("Outro destaque #{i}", days_ago: 9, featured: true).update_columns(updated_at: 1.year.ago) }

    get root_path

    expect(names(:featured_products).first).to eq("Destaque antigo")
    expect(names(:featured_products)).to include("Destaque novo")
    expect(names(:featured_products)).not_to include("Comum")
    expect(names(:featured_products).size).to eq(4)
  end

  it "fills 'Cartas em Destaque' with the newest singles and links it to the singles listing" do
    product("Carta velha", days_ago: 30, single: true)
    product("Carta nova", days_ago: 1, single: true)
    product("Booster Box", days_ago: 1)

    get root_path

    expect(names(:collection_products)).to eq([ "Carta nova", "Carta velha" ])
    expect(response.body).to include(%(href="/t/#{singles.permalink}"))
  end

  it "puts the newest sealed products in the call-to-action block" do
    product("Carta", days_ago: 1, single: true)
    product("ETB", days_ago: 2)
    product("Booster Box", days_ago: 1)

    get root_path

    expect(names(:cta_collection_products)).to eq([ "Booster Box", "ETB" ])
  end

  it "shows the newest products in 'Chegaram Agora' without repeating ones already on the page" do
    product("Destaque", days_ago: 0, featured: true)
    5.times { |i| product("Carta #{i}", days_ago: i + 1, single: true) }

    get root_path

    expect(names(:new_arrivals)).to eq([ "Carta 4" ])
    shown = %i[featured_products collection_products cta_collection_products new_arrivals].flat_map { names(it) }
    expect(shown).to eq(shown.uniq)
  end
end
