# frozen_string_literal: true

# The header and the search sidebar present the same three dimensions — origin,
# product type and collection — so the queries behind them live here instead of
# being rebuilt in each view.
#
# Each reads a taxonomy by name and tolerates it being absent, so a database
# that hasn't been seeded renders an empty nav rather than raising.
module MainNavigationHelper
  # Singles are a product type like any other in the data, but the header gives
  # them their own entry instead of burying them in the "Produtos" dropdown.
  SINGLES_TAXON_NAME = "Cartas Avulsas"

  def nav_origin_taxons
    @nav_origin_taxons ||= nav_taxons("Origem")
  end

  def nav_product_type_taxons
    @nav_product_type_taxons ||= nav_taxons("Tipo").reject { |taxon| taxon.name == SINGLES_TAXON_NAME }
  end

  def nav_singles_taxon
    @nav_singles_taxon ||= nav_taxons("Tipo").find { |taxon| taxon.name == SINGLES_TAXON_NAME }
  end

  # Newest first. NULLS LAST keeps a collection with no release date out of the
  # front of the menu, where it would otherwise sort above everything.
  def nav_collection_taxons
    @nav_collection_taxons ||= nav_taxons("Coleções", order: Arel.sql("released_on DESC NULLS LAST"))
  end

  def nav_recent_collections(limit: 7)
    nav_collection_taxons.first(limit)
  end

  private

  def nav_taxons(taxonomy_name, order: :lft)
    taxonomy = Spree::Taxonomy.find_by(name: taxonomy_name)
    return [] unless taxonomy

    taxonomy.taxons.where.not(parent_id: nil).order(order).to_a
  end
end
