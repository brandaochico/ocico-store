# frozen_string_literal: true

# Brazilian addresses have a street number and a neighbourhood (bairro) as
# fields of their own — Correios, Boleto and freight quotes all ask for them
# separately — and an 8-digit CEP. address1 is the street, address2 the
# optional complement.
#
# Only applied to BR addresses: the sample-data zones (North America/EU) and
# Solidus' own US-based factories keep the stock rules.
#
# Callbacks are registered by method name on purpose: this file is loaded
# twice (Zeitwerk, and deface's loader for app/overrides), and Rails dedupes
# symbol callbacks, whereas `validates ...` would register every rule twice.
module BrazilianAddress
  def self.prepended(base)
    base.before_validation :normalize_brazilian_fields
    base.validate :validate_brazilian_fields
  end

  def brazilian?
    country&.iso == "BR"
  end

  private

  def normalize_brazilian_fields
    return unless brazilian?

    digits = zipcode.to_s.gsub(/\D/, "")
    self.zipcode = "#{digits[0, 5]}-#{digits[5, 3]}" if digits.length == 8
    self.street_number = street_number.to_s.strip.presence
    self.neighborhood = neighborhood.to_s.strip.presence
  end

  def validate_brazilian_fields
    return unless brazilian?

    errors.add(:street_number, :blank) if street_number.blank?
    errors.add(:neighborhood, :blank) if neighborhood.blank?
    errors.add(:zipcode, :invalid) if zipcode.present? && !zipcode.match?(/\A\d{5}-\d{3}\z/)
  end

  Spree::Address.prepend self
end
