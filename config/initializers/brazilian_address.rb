# frozen_string_literal: true

# Street number and neighbourhood columns (see app/overrides/brazilian_address.rb).
# Mutated in place: checkout, payment-source and both admins' address params
# all hold a reference to this same array. The address book list is a copy
# (address_attributes + [:default]), so it gets them separately.
Spree::PermittedAttributes.address_attributes.unshift(:street_number, :neighborhood)
Spree::PermittedAttributes.address_book_attributes.unshift(:street_number, :neighborhood)
