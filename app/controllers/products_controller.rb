# frozen_string_literal: true

class ProductsController < StoreController
  before_action :load_product, only: :show
  before_action :load_taxon, only: :index

  helper "spree/products", "spree/taxons", "taxon_filters"

  respond_to :html

  rescue_from Spree::Config.searcher_class::InvalidOptions do |error|
    raise ActionController::BadRequest.new, error.message
  end

  # The full product list is always alphabetical — the owner's rule
  # (2026-11-20). Collated as Brazilian Portuguese so accents and case sort
  # the way people read them ("Énergie" next to "Energy", not after "Zekrom");
  # the ICU collation ships with the Postgres images used in dev and production.
  # The searcher's query is SELECT DISTINCT spree_products.*, and Postgres only
  # orders such a query by expressions in its select list — so the collated
  # name is also selected. The order repeats the expression rather than using
  # the alias: with a category filter Rails first runs an ids-only DISTINCT
  # subquery, which copies the order terms but not our select.
  COLLATED_NAME = %(spree_products.name COLLATE "pt-BR-x-icu")

  # Browsing, this is the *products* page — sealed items only; singles have
  # their own listing ("Cartas Avulsas"), just as sealed items never show up
  # there. A search (keywords, e.g. from the header's "Ver todos os resultados")
  # covers everything: someone searching "Charizard" means the card.
  def index
    @searcher = build_searcher(params.merge(include_images: true))
    @sealed_only = params[:keywords].blank?
    products = @searcher.retrieve_products
    singles_ids = SinglesCatalog.product_ids if @sealed_only
    products = products.where.not(id: singles_ids) if singles_ids
    @products = products
      .select(Spree::Product.arel_table[Arel.star], Arel.sql("#{COLLATED_NAME} AS alphabetical_name"))
      .reorder(Arel.sql("#{COLLATED_NAME} ASC"), Arel.sql("spree_products.id ASC"))
  end

  def show
    @variants = @product.
      variants_including_master.
      display_includes.
      with_prices(current_pricing_options).
      includes([ :option_values, :images ])

    @product_properties = @product.product_properties.includes(:property)
    @taxon = Spree::Taxon.find(params[:taxon_id]) if params[:taxon_id]
    @similar_products = @product.similar_products
  end

  private

  def accurate_title
    if @product
      @product.meta_title.blank? ? @product.name : @product.meta_title
    else
      super
    end
  end

  def load_product
    if spree_current_user.try(:has_spree_role?, "admin")
      @products = Spree::Product.with_discarded
    else
      @products = Spree::Product.available
    end
    @product = @products.friendly.find(params[:id])

    # Redirects to the correct product URL if the requested slug does not match the current product's slug.
    # This ensures that outdated or ID URLs always resolve to the latest canonical URL.
    redirect_to @product, status: :moved_permanently if params[:id] != @product.slug
  end

  def load_taxon
    @taxon = Spree::Taxon.find(params[:taxon]) if params[:taxon].present?
  end
end
