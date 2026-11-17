# frozen_string_literal: true

require "net/http"

module MelhorEnvio
  # Thin wrapper over Melhor Envio's freight quote endpoint
  # (POST /api/v2/me/shipment/calculate).
  #
  # Timeouts are deliberately short: the quote runs while the customer waits on
  # checkout's delivery step, and a slow carrier API must turn into "use the
  # fallback rate", never into a hung page (see MelhorEnvio::Quote).
  class Client
    SANDBOX_URL = "https://sandbox.melhorenvio.com.br"
    PRODUCTION_URL = "https://melhorenvio.com.br"
    OPEN_TIMEOUT = 3
    READ_TIMEOUT = 6

    class Error < StandardError
      attr_reader :status, :body

      def initialize(message, status: nil, body: nil)
        super(message)
        @status = status
        @body = body
      end
    end

    def self.from_config(config = Rails.application.config.x.melhor_envio)
      new(token: config[:token], sandbox: config[:sandbox], contact_email: config[:contact_email])
    end

    def initialize(token:, sandbox:, contact_email: nil)
      @token = token
      @base_url = sandbox ? SANDBOX_URL : PRODUCTION_URL
      @contact_email = contact_email
    end

    # from/to: CEPs (any formatting; only digits are sent).
    # products: [{ id:, width:, height:, length:, weight:, insurance_value:, quantity: }]
    #   in cm, kg and BRL per unit — Melhor Envio packs them into boxes itself.
    # Returns one hash per carrier service; a service that can't take this
    # shipment comes back with an "error" key instead of a price.
    def calculate(from:, to:, products:)
      post("/api/v2/me/shipment/calculate", {
        from: { postal_code: digits(from) },
        to: { postal_code: digits(to) },
        products: products
      })
    end

    private

    def post(path, payload)
      uri = URI.join(@base_url, path)
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{@token}"
      request["Accept"] = "application/json"
      request["Content-Type"] = "application/json"
      # Required by Melhor Envio: "Application (technical contact email)".
      request["User-Agent"] = [ "ocico store", (@contact_email && "(#{@contact_email})") ].compact.join(" ")
      request.body = payload.to_json

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                                 open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.request(request)
      end

      parse(response)
    rescue Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError => error
      raise Error.new("Melhor Envio unreachable: #{error.class}: #{error.message}")
    end

    def parse(response)
      body = response.body.present? ? JSON.parse(response.body) : {}
      return body if response.is_a?(Net::HTTPSuccess)

      raise Error.new(body.is_a?(Hash) && body["message"] || "Melhor Envio returned HTTP #{response.code}",
                      status: response.code.to_i, body: body)
    rescue JSON::ParserError
      raise Error.new("Melhor Envio returned HTTP #{response.code}", status: response.code.to_i)
    end

    def digits(cep)
      cep.to_s.gsub(/\D/, "")
    end
  end
end
