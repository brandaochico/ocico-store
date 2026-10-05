# frozen_string_literal: true

module MercadoPago
  # The Spree payment source for a Pix or Boleto charge: what the customer typed
  # in (CPF/CNPJ) plus what Mercado Pago returned when the charge was created —
  # the QR code / boleto line the customer needs to actually pay.
  class PaymentSource < Spree::PaymentSource
    self.table_name = "mercado_pago_payment_sources"

    before_validation { self.payer_document = TaxDocument.normalize(payer_document).presence }

    validates :payer_document, presence: true, if: :document_required?
    validate :payer_document_is_valid, if: -> { payer_document.present? }

    def pix?
      payment_method.is_a?(PixPaymentMethod)
    end

    def boleto?
      payment_method.is_a?(BoletoPaymentMethod)
    end

    def charge_created?
      mp_order_id.present?
    end

    def expired?
      expires_at.present? && expires_at.past?
    end

    # Pix and Boleto are paid by the customer, not captured by us; once paid,
    # the only thing left to do is refund.
    def actions
      %w[void credit]
    end

    private

    def document_required?
      boleto?
    end

    def payer_document_is_valid
      errors.add(:payer_document, :invalid) unless TaxDocument.valid?(payer_document)
    end
  end
end
