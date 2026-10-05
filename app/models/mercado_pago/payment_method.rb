# frozen_string_literal: true

module MercadoPago
  # Base class for the Pix and Boleto payment methods. Abstract: only the
  # subclasses are registered (config/initializers/mercado_pago.rb) and seeded.
  class PaymentMethod < Spree::PaymentMethod
    preference :access_token, :string
    preference :public_key, :string

    def payment_source_class
      PaymentSource
    end

    # Always false, whatever the column says: the charge is created at order
    # completion (Spree's authorize step) and becomes "completed" only when
    # Mercado Pago confirms the customer paid. Spree's purchase path would mark
    # it completed immediately, i.e. before any money moved.
    def auto_capture?
      false
    end

    def partial_name
      "mercado_pago_#{self.class.name.demodulize.delete_suffix("PaymentMethod").underscore}"
    end

    protected

    def gateway_class
      Gateway
    end
  end
end
