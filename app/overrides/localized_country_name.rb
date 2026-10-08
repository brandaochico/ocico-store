# frozen_string_literal: true

# Spree::Country#name comes from Carmen, which only ships English. The
# translated name lives in config/locales/<locale>/countries.yml; #name is
# left alone because it's also the stored column (admin forms write it back).
module LocalizedCountryName
  def localized_name
    I18n.t(iso, scope: :countries, default: name)
  end

  Spree::Country.prepend self
end
