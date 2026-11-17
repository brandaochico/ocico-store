# frozen_string_literal: true

module MelhorEnvio
  # One Melhor Envio quote for one Solidus package: every carrier service's
  # price and delivery time for shipping these items from the stock location's
  # CEP to the order's shipping CEP.
  #
  # Solidus asks each shipping method's calculator separately (one method per
  # carrier service), so the quote is cached per package contents + CEPs: the
  # first calculator pays for the API call, the rest read the result. Its own
  # in-process cache rather than Rails.cache, because test runs a null store
  # and the quote has to be shared within a single estimate everywhere.
  #
  # A failed call (timeout, 5xx, bad token, malformed response, stock location
  # without a CEP) is cached briefly too, so one estimate doesn't retry it once per carrier; the
  # fallback flat rate shows up instead (MelhorEnvio::FallbackCalculator).
  class Quote
    Rate = Data.define(:service_id, :price, :min_days, :max_days)

    SUCCESS_TTL = 30.minutes
    FAILURE_TTL = 1.minute

    def self.for(package, config: Rails.application.config.x.melhor_envio)
      return new(status: :unconfigured) if config[:token].blank?

      request = build_request(package)
      return new(status: :failed) unless request

      key = cache_key(request)
      cache.read(key) || fetch(request, config).tap do |quote|
        cache.write(key, quote, expires_in: quote.ok? ? SUCCESS_TTL : FAILURE_TTL)
      end
    end

    def self.cache
      @cache ||= ActiveSupport::Cache::MemoryStore.new(size: 4.megabytes)
    end

    def self.build_request(package)
      from = package.stock_location&.zipcode
      to = package.shipment&.order&.ship_address&.zipcode

      if from.blank?
        Rails.logger.warn("[MelhorEnvio] stock location #{package.stock_location&.name.inspect} has no CEP; can't quote freight")
        return
      end
      return if to.blank?

      products = package.contents.group_by(&:variant).map do |variant, items|
        dimensions = PackageDimensions.for(variant)
        {
          id: variant.id.to_s,
          width: dimensions.width,
          height: dimensions.height,
          length: dimensions.length,
          weight: dimensions.weight,
          # Per unit; Melhor Envio multiplies by quantity. Declared value is
          # what the carrier insures, and caps which services can take it.
          insurance_value: items.first.line_item.price.to_f.round(2),
          quantity: items.sum(&:quantity)
        }
      end

      { from:, to:, products: products.sort_by { |product| product[:id] } }
    end

    def self.cache_key(request)
      "melhor_envio/quote/#{Digest::SHA256.hexdigest(request.to_json)}"
    end

    def self.fetch(request, config)
      services = Client.from_config(config).calculate(**request)
      new(status: :ok, rates: parse(services))
    rescue Client::Error => error
      failed(error, request)
    rescue StandardError => error
      # A response we couldn't make sense of (an odd price, a malformed
      # service entry). Freight must never turn the delivery step into a 500:
      # report it and let the fallback flat rate keep checkout going.
      failed(error, request)
    end

    def self.failed(error, request)
      Rails.logger.warn("[MelhorEnvio] quote failed: #{error.class}: #{error.message}")
      Rails.error.report(error, handled: true, context: { cep: request[:to] })
      new(status: :failed)
    end

    def self.parse(services)
      Array(services).filter_map do |service|
        next if service["error"].present? || service["custom_price"].blank?

        range = service["custom_delivery_range"] || {}
        days = service["custom_delivery_time"]
        Rate.new(
          service_id: service["id"].to_i,
          price: BigDecimal(service["custom_price"].to_s),
          min_days: range["min"] || days,
          max_days: range["max"] || days
        )
      end.index_by(&:service_id)
    end

    private_class_method :build_request, :cache_key, :fetch, :failed, :parse

    attr_reader :status

    def initialize(status:, rates: {})
      @status = status
      @rates = rates
    end

    def ok? = status == :ok


    # nil when this carrier service can't take the shipment (or the quote
    # failed): Solidus then simply doesn't offer that shipping method.
    def rate_for(service_id)
      @rates[service_id.to_i]
    end
  end
end
