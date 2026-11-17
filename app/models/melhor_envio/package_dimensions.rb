# frozen_string_literal: true

module MelhorEnvio
  # Weight and dimensions of one unit of a variant, *as shipped* (packaging
  # included), in the units Melhor Envio takes: kg and whole centimetres.
  #
  # A variant's own measurements win when they are complete (weight plus
  # height/width/depth, entered in the admin in kg/cm); then its product's
  # master variant's; otherwise a default by the product's "Tipo" taxon.
  # The defaults are estimates for a typical packed unit — replace them with
  # real measurements in the admin as products are weighed.
  class PackageDimensions
    Dimensions = Data.define(:weight, :height, :width, :length)

    # Keyed by "Tipo" taxon name (db/seeds/catalog.rb#product_types).
    DEFAULTS_BY_TYPE = {
      # A card in a sleeve + top loader, inside a padded envelope. 16x11 is
      # the Correios minimum, so this is also what lets Mini Envios quote it.
      "Cartas Avulsas" => Dimensions.new(weight: 0.05, height: 2, width: 11, length: 16),
      "Booster Unitário" => Dimensions.new(weight: 0.06, height: 2, width: 13, length: 18),
      "Blister" => Dimensions.new(weight: 0.2, height: 4, width: 18, length: 25),
      "Mini Booster Box" => Dimensions.new(weight: 0.4, height: 8, width: 12, length: 18),
      "Booster Box" => Dimensions.new(weight: 1.0, height: 12, width: 20, length: 25),
      "ETB" => Dimensions.new(weight: 1.2, height: 12, width: 22, length: 30),
      "Caixas Colecionáveis" => Dimensions.new(weight: 1.0, height: 10, width: 25, length: 30)
    }.freeze

    # Products with no "Tipo" (or one added later without a default here) are
    # quoted as a booster box: big enough not to undercharge most sealed
    # products.
    FALLBACK = DEFAULTS_BY_TYPE.fetch("Booster Box")

    TYPE_TAXONOMY = "Tipo"

    def self.for(variant)
      new(variant).dimensions
    end

    def initialize(variant)
      @variant = variant
    end

    def dimensions
      measured(@variant) || measured(@variant.product.master) || default_for_type
    end

    private

    def measured(variant)
      return unless variant
      values = [ variant.weight, variant.height, variant.width, variant.depth ]
      return unless values.all? { |value| value.to_d.positive? }

      Dimensions.new(
        weight: variant.weight.to_f,
        height: variant.height.ceil,
        width: variant.width.ceil,
        length: variant.depth.ceil
      )
    end

    def default_for_type
      type_names = @variant.product.taxons
        .joins(:taxonomy).where(spree_taxonomies: { name: TYPE_TAXONOMY })
        .pluck(:name)

      type_names.lazy.filter_map { |name| DEFAULTS_BY_TYPE[name] }.first || FALLBACK
    end
  end
end
