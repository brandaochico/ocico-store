# frozen_string_literal: true

require "net/http"

module MercadoPago
  # Thin wrapper over the Mercado Pago Orders API (/v1/orders).
  #
  # Plain Net::HTTP rather than the mercadopago-sdk gem: we use five endpoints,
  # and owning the request makes the idempotency keys and timeouts explicit.
  class Client
    BASE_URL = "https://api.mercadopago.com"

    class Error < StandardError
      attr_reader :status, :body

      def initialize(message, status: nil, body: nil)
        super(message)
        @status = status
        @body = body
      end
    end

    def initialize(access_token:)
      @access_token = access_token
    end

    def create_order(payload, idempotency_key:)
      request(:post, "/v1/orders", payload, idempotency_key:)
    end

    def get_order(order_id)
      request(:get, "/v1/orders/#{escape(order_id)}")
    end

    def cancel_order(order_id, idempotency_key:)
      request(:post, "/v1/orders/#{escape(order_id)}/cancel", nil, idempotency_key:)
    end

    def refund_order(order_id, payment_id:, amount:, idempotency_key:)
      payload = { transactions: [ { id: payment_id, amount: amount } ] }
      request(:post, "/v1/orders/#{escape(order_id)}/refund", payload, idempotency_key:)
    end

    private

    def request(method, path, payload = nil, idempotency_key: nil)
      uri = URI.join(BASE_URL, path)
      request = (method == :get ? Net::HTTP::Get : Net::HTTP::Post).new(uri)
      request["Authorization"] = "Bearer #{@access_token}"
      request["Content-Type"] = "application/json"
      request["X-Idempotency-Key"] = idempotency_key if idempotency_key
      request.body = payload.to_json if payload

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 20) do |http|
        http.request(request)
      end

      parse(response)
    rescue Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError => error
      # Solidus' payment processing turns this into a "can't reach the gateway"
      # message instead of a 500.
      raise ActiveMerchant::ConnectionError.new(error.message, error)
    end

    def parse(response)
      body = response.body.present? ? JSON.parse(response.body) : {}
      return body if response.is_a?(Net::HTTPSuccess)

      raise Error.new(error_message(body, response), status: response.code.to_i, body: body)
    rescue JSON::ParserError
      raise Error.new("Mercado Pago returned HTTP #{response.code}", status: response.code.to_i)
    end

    def error_message(body, response)
      messages = Array(body["errors"]).map do |error|
        [ error["message"], *Array(error["details"]) ].compact.join(": ")
      end
      messages << body["message"] if messages.empty? && body["message"]
      messages.presence&.join("; ") || "Mercado Pago returned HTTP #{response.code}"
    end

    def escape(segment)
      ERB::Util.url_encode(segment)
    end
  end
end
