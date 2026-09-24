# frozen_string_literal: true

Devise.secret_key = "228fee4867d687f89c3fefca99a16f73cd3232ff060ccb350b36141fd7def82121606833f9d34a0fb0b9638dbcaa5f1866515072ec605dec7b9c80965520e51e"
Devise.email_regexp = Spree::Config[:default_email_regexp]
Devise.setup do |config|
  config.parent_controller = "StoreDeviseController"
  config.mailer = "UserMailer"
end
