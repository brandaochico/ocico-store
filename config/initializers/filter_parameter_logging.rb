# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
#
# :document, :cpf and :cnpj cover the Boleto payer's CPF/CNPJ
# (payment_source[N][payer_document]) — personal data under the LGPD, which has
# no business sitting in plain text in the request log.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :document, :cpf, :cnpj
]
