# frozen_string_literal: true

require "openssl"

module MercadoPago
  # Verifies a webhook's `x-signature` header (HMAC-SHA256 with the
  # application's webhook secret), mirroring the validator in Mercado Pago's
  # official SDKs (sdk-ruby lib/mercadopago/webhook/validator.rb).
  module WebhookSignature
    module_function

    def valid?(x_signature:, x_request_id:, data_id:, secret:)
      return false if secret.blank? || x_signature.blank?

      timestamp, received = parse(x_signature)
      return false if timestamp.blank? || received.blank?

      # The SDKs sign data.id as received; older docs said to lowercase
      # alphanumeric ids first. Accept either — both still require the secret.
      [ data_id, data_id&.downcase ].uniq.any? do |id|
        expected = OpenSSL::HMAC.hexdigest("SHA256", secret, manifest(id, x_request_id, timestamp))
        ActiveSupport::SecurityUtils.secure_compare(expected, received)
      end
    end

    def parse(header)
      parts = header.split(",").to_h { |part| part.split("=", 2).map { |s| s.to_s.strip } }
      [ parts["ts"], parts["v1"] ]
    end

    def manifest(data_id, request_id, timestamp)
      parts = []
      parts << "id:#{data_id}" if data_id.present?
      parts << "request-id:#{request_id}" if request_id.present?
      parts << "ts:#{timestamp}"
      "#{parts.join(";")};"
    end
  end
end
