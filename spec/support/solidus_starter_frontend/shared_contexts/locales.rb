# frozen_string_literal: true

RSpec.shared_context 'fr locale' do
  before do
    I18n.available_locales = [ :"pt-BR", :en, :fr ]
    I18n.backend.store_translations(:fr, spree: {
      i18n: { this_file_language: "Français" },
      cart: 'Panier',
      shopping_cart: 'Panier',
      locale_changed: 'Paramètres régionaux changés',
      your_cart_is_empty: 'Votre panier est vide'
    })
  end

  after do
    # Must match config.i18n.available_locales in config/application.rb, or any
    # spec running after this one (random order) sees Spree.i18n_available_locales
    # drop pt-BR and hits "I18n.locale = :en" is not a valid locale errors.
    I18n.available_locales = [ :"pt-BR", :en ]
    I18n.locale = I18n.default_locale # reset locale after each spec.
    I18n.reload!
  end
end
