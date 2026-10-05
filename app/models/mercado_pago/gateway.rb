# frozen_string_literal: true

module MercadoPago
  # The object Spree::PaymentMethod delegates authorize/void/credit to, speaking
  # ActiveMerchant responses so Spree::Payment's state machine handles results
  # the same way it does for any card gateway.
  #
  # "authorize" is a slight misnomer here: it creates the Pix/Boleto charge and
  # leaves the payment *pending* until the customer actually pays. That
  # transition comes later, from PaymentSynchronizer — never from this class.
  class Gateway
    # How long a Pix QR code stays payable, i.e. how long stock is held for an
    # unpaid Pix order (ISO 8601 duration). Boleto keeps Mercado Pago's default
    # due date (3 days).
    PIX_EXPIRATION = "PT4H"

    METHODS = {
      pix: { id: "pix", type: "bank_transfer" },
      boleto: { id: "boleto", type: "ticket" }
    }.freeze

    def initialize(options)
      @client = Client.new(access_token: options.fetch(:access_token))
      @test = options[:test]
    end

    def authorize(amount_cents, source, options = {})
      order = @client.create_order(
        order_payload(amount_cents, source, options),
        # options[:order_id] is "<order number>-<payment number>", unique per
        # Spree payment: a retried request returns the same charge instead of
        # creating a second one.
        idempotency_key: options.fetch(:order_id)
      )

      return failure("Mercado Pago order #{order["id"]} is #{order["status"]}") if order["status"] == "failed"

      source.update!(charge_attributes(order))
      success(order["id"], "Mercado Pago order #{order["id"]} created")
    rescue Client::Error => error
      failure(error.message)
    end

    # Cancels an unpaid charge, so the QR code / boleto can no longer be paid.
    # Fails once the customer has paid — Spree::Payment::Cancellation then
    # falls back to a refund.
    def void(order_id, _options = {})
      @client.cancel_order(order_id, idempotency_key: "#{order_id}-cancel")
      success(order_id, "Mercado Pago order #{order_id} canceled")
    rescue Client::Error => error
      failure(error.message)
    end

    def credit(amount_cents, order_id, options = {})
      refund = options.fetch(:originator)
      payment = refund.payment

      order = @client.refund_order(
        order_id,
        payment_id: payment.source.mp_payment_id,
        amount: format_amount(amount_cents),
        # Count of refunds already recorded: distinct per refund of this
        # payment, stable if this same refund's request is retried.
        idempotency_key: "#{order_id}-refund-#{payment.refunds.where.not(id: nil).count}-#{amount_cents}"
      )

      refund_id = Array(order.dig("transactions", "refunds")).last&.fetch("id", nil)
      success(refund_id || order_id, "Mercado Pago refund created")
    rescue Client::Error => error
      failure(error.message)
    end

    private

    def order_payload(amount_cents, source, options)
      amount = format_amount(amount_cents)
      kind = source.pix? ? :pix : :boleto

      payment = { amount: amount, payment_method: METHODS.fetch(kind) }
      payment[:expiration_time] = PIX_EXPIRATION if kind == :pix

      {
        type: "online",
        external_reference: options.fetch(:order_id),
        total_amount: amount,
        payer: payer(source, options),
        transactions: { payments: [ payment ] }
      }
    end

    def payer(source, options)
      address = options[:billing_address] || {}
      first_name, last_name = address[:name].to_s.strip.split(/\s+/, 2)

      payer = {
        email: Rails.configuration.x.mercado_pago[:test_payer_email] || options.fetch(:email),
        first_name: first_name,
        last_name: last_name
      }.compact

      if source.payer_document.present?
        payer[:identification] = {
          type: TaxDocument.type(source.payer_document),
          number: source.payer_document
        }
      end

      payer[:address] = boleto_address(address) if source.boleto?
      payer
    end

    # Boleto requires a split street/number/neighbourhood address, which
    # Solidus' two free-form lines don't have. Best effort until the checkout
    # collects a proper Brazilian address.
    def boleto_address(address)
      street, number = address[:address1].to_s.split(/,\s*(?=\d)/, 2)

      {
        zip_code: address[:zip].to_s.gsub(/\D/, ""),
        street_name: street.to_s.strip,
        street_number: number.to_s.strip.presence || "S/N",
        neighborhood: address[:address2].to_s.strip.presence || "-",
        city: address[:city],
        state: address[:state]
      }
    end

    def charge_attributes(order)
      payment = order.dig("transactions", "payments", 0) || {}
      method = payment["payment_method"] || {}

      {
        mp_order_id: order["id"],
        mp_payment_id: payment["id"],
        expires_at: payment["date_of_expiration"],
        qr_code: method["qr_code"],
        qr_code_base64: method["qr_code_base64"],
        ticket_url: method["ticket_url"],
        digitable_line: method["digitable_line"],
        barcode_content: method["barcode_content"]
      }
    end

    def format_amount(cents)
      format("%.2f", BigDecimal(cents) / 100)
    end

    def success(authorization, message)
      ActiveMerchant::Billing::Response.new(true, message, {}, authorization: authorization, test: @test)
    end

    def failure(message)
      ActiveMerchant::Billing::Response.new(false, message, { "message" => message }, test: @test)
    end
  end
end
