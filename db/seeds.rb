# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
Spree::Core::Engine.load_seed

# solidus_auth_devise creates the first admin from ADMIN_EMAIL/ADMIN_PASSWORD,
# falling back to admin@example.com / test123. In production that fallback
# would be a publicly known login, and db:prepare seeds on its own the first
# time it creates the database (bin/docker-entrypoint), with no ENV passed.
# So production takes the admin from the encrypted credentials (`admin:`) and
# refuses to seed without one.
# Development keeps the documented admin@example.com / test123.
if Rails.env.production?
  ENV["ADMIN_EMAIL"] ||= Rails.application.credentials.dig(:admin, :email)
  ENV["ADMIN_PASSWORD"] ||= Rails.application.credentials.dig(:admin, :password)
  if ENV["ADMIN_EMAIL"].blank? || ENV["ADMIN_PASSWORD"].blank?
    abort "Refusing to seed production without an admin login: set admin.email and admin.password in the credentials."
  end
end
Spree::Auth::Engine.load_seed

load Rails.root.join("db/seeds/catalog.rb")
load Rails.root.join("db/seeds/shipping.rb")

# Creates the Spree::RefundReason that solidus_stripe attributes its refunds to.
SolidusStripe::Engine.load_seed

load Rails.root.join("db/seeds/payment_methods.rb")
