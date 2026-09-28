# frozen_string_literal: true

class HomeController < StoreController
  helper "spree/products"
  respond_to :html

  def index
    @searcher = build_searcher(params.merge(include_images: true))
    @products = @searcher.retrieve_products

    # Split products into groups of 4 for the homepage blocks — the product
    # rows show four cards, and widening the cards alone would just leave a gap
    # if the block were still handed three products.
    # You probably want to remove this logic and use your own!
    homepage_groups = @products.in_groups_of(4, false)
    @featured_products = homepage_groups[0]
    @collection_products = homepage_groups[1]
    @cta_collection_products = homepage_groups[2]
    @new_arrivals = homepage_groups[3]
  end
end
