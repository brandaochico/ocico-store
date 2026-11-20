# frozen_string_literal: true

# Which products are singles ("Cartas Avulsas", in the Tipo taxonomy) — the
# split between the singles listing and everything else (sealed products).
# Used by the home page blocks and the all-products page.
module SinglesCatalog
  module_function

  def taxon
    Spree::Taxon.joins(:taxonomy)
      .find_by(name: MainNavigationHelper::SINGLES_TAXON_NAME, spree_taxonomies: { name: "Tipo" })
  end

  # Ids of the products filed under the singles taxon (or its children), as a
  # subquery; nil when the taxon doesn't exist.
  def product_ids(singles_taxon = taxon)
    return unless singles_taxon

    Spree::Classification.where(taxon_id: singles_taxon.self_and_descendants.select(:id)).select(:product_id)
  end
end
