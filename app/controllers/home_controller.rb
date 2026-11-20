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
    @singles_taxon = SinglesCatalog.taxon
    singles_ids = SinglesCatalog.product_ids(@singles_taxon)
    @collection_products = singles_ids ? pick.(newest(available.where(id: singles_ids)), ROW_LIMIT) : []
    sealed = singles_ids ? available.where.not(id: singles_ids) : available
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
end
