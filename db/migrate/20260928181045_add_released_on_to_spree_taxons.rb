class AddReleasedOnToSpreeTaxons < ActiveRecord::Migration[8.1]
  # The header lists the seven most recent collections, newest first, and
  # Solidus taxons carry no date of their own — only a manual `position`. A real
  # release date is the honest source for "most recent", and it's data the TCG
  # publishes anyway, so it can also drive "new arrivals" and catalogue sorting
  # later instead of a hand-maintained ordering.
  #
  # Nullable because it only means something for the Coleções taxonomy; origin
  # and product-type taxons have no release date.
  def change
    add_column :spree_taxons, :released_on, :date
    add_index :spree_taxons, :released_on
  end
end
