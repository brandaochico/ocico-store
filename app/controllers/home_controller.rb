# frozen_string_literal: true

# The home page's blocks, each chosen on purpose (it used to be the first
# twelve products in database order, split in fours):
#
#   destaques             products marked "Destaque na home" in the admin
#   Cartas em Destaque    the newest singles ("Cartas Avulsas")
#   catalog call to action  the newest sealed products (anything else)
#   Chegaram Agora        the newest products of all
#
# "Newest" is by available_on — when the product went on sale. A product
# shows up once: each block skips what an earlier block already shows, so a
# small catalog doesn't repeat itself down the page (and a block with nothing
# left simply isn't rendered).
class HomeController < StoreController
  helper "spree/products"
  respond_to :html

  FEATURED_LIMIT = 4
  ROW_LIMIT = 4
  CTA_LIMIT = 3 # the call-to-action block shows three; the banner reuses the third

  def index
    shown = []
    pick = ->(scope, limit) { scope.where.not(id: shown).limit(limit).to_a.tap { |found| shown.concat(found.map(&:id)) } }

    @featured_products = pick.(available.featured.reorder(updated_at: :desc), FEATURED_LIMIT)
    @singles_taxon = singles_taxon
    @collection_products = @singles_taxon ? pick.(newest(available.where(id: product_ids_in(@singles_taxon))), ROW_LIMIT) : []
    sealed = @singles_taxon ? available.where.not(id: product_ids_in(@singles_taxon)) : available
    @cta_collection_products = pick.(newest(sealed), CTA_LIMIT)
    @new_arrivals = pick.(newest(available), ROW_LIMIT)
  end

  private

  def available
    Spree::Product.display_includes.available
  end

  def newest(scope)
    scope.reorder(available_on: :desc, id: :desc)
  end

  def singles_taxon
    Spree::Taxon.joins(:taxonomy)
      .find_by(name: MainNavigationHelper::SINGLES_TAXON_NAME, spree_taxonomies: { name: "Tipo" })
  end

  def product_ids_in(taxon)
    Spree::Classification.where(taxon_id: taxon.self_and_descendants.select(:id)).select(:product_id)
  end
end
