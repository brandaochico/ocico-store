# frozen_string_literal: true

# The full list of collections, reached from "Ver todas as coleções..." at the
# bottom of the header dropdown, which only shows the seven most recent.
class CollectionsController < StoreController
  respond_to :html

  def index
    @collections = helpers.nav_collection_taxons
  end

  private

  def accurate_title
    t("storefront.collections.title")
  end
end
