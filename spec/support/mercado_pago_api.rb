# frozen_string_literal: true

# Canned Mercado Pago Orders API responses, shaped after real sandbox replies.
module MercadoPagoApi
  BASE = "https://api.mercadopago.com"

  module_function

  def order_response(id: "ORDTST01SPEC", status: "action_required", status_detail: "waiting_transfer",
                     amount: "10.00", method: :pix, paid_amount: nil, refunds: nil)
    payment_method =
      if method == :pix
        {
          "id" => "pix", "type" => "bank_transfer",
          "ticket_url" => "https://www.mercadopago.com.br/sandbox/payments/1/ticket",
          "qr_code" => "00020126580014br.gov.bcb.pix0136spec",
          "qr_code_base64" => "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
        }
      else
        {
          "id" => "boleto", "type" => "ticket",
          "ticket_url" => "https://www.mercadopago.com.br/sandbox/payments/1/ticket",
          "barcode_content" => "23796159200000050003380260601043100200633330",
          "digitable_line" => "23793380296060104310602006333302615920000005000"
        }
      end

    transactions = {
      "payments" => [
        {
          "id" => "PAY01SPEC",
          "amount" => amount,
          "date_of_expiration" => "2026-10-05T05:00:00.000+00:00",
          "status" => status,
          "status_detail" => status_detail,
          "payment_method" => payment_method
        }
      ]
    }
    transactions["refunds"] = refunds if refunds

    {
      "id" => id,
      "status" => status,
      "status_detail" => status_detail,
      "total_amount" => amount,
      "total_paid_amount" => paid_amount,
      "currency" => "BRL",
      "transactions" => transactions
    }
  end

  def json(body, status: 200)
    { status: status, body: body.to_json, headers: { "Content-Type" => "application/json" } }
  end
end
