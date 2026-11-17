# frozen_string_literal: true

# Canned Melhor Envio quote responses, shaped after the API's documented
# reply: one entry per carrier service, and services that can't take the
# shipment come back with an "error" instead of a price.
module MelhorEnvioApi
  SANDBOX_URL = "https://sandbox.melhorenvio.com.br/api/v2/me/shipment/calculate"
  PRODUCTION_URL = "https://melhorenvio.com.br/api/v2/me/shipment/calculate"

  module_function

  def config(**overrides)
    { token: "me-spec-token", sandbox: true, contact_email: "dev@example.com" }.merge(overrides)
  end

  def service(id, name, price:, min:, max:)
    {
      "id" => id,
      "name" => name,
      "price" => price,
      "custom_price" => price,
      "discount" => "0.00",
      "currency" => "R$",
      "delivery_time" => max,
      "delivery_range" => { "min" => min, "max" => max },
      "custom_delivery_time" => max,
      "custom_delivery_range" => { "min" => min, "max" => max },
      "company" => { "id" => 1, "name" => "Correios" }
    }
  end

  def unavailable(id, name, error = "Transportadora não atende este trecho.")
    { "id" => id, "name" => name, "error" => error, "company" => { "id" => 1, "name" => "Correios" } }
  end

  def quote_response
    [
      service(1, "PAC", price: "25.40", min: 5, max: 7),
      service(2, "SEDEX", price: "41.90", min: 1, max: 2),
      unavailable(3, ".Package"),
      unavailable(17, "Mini Envios", "Valor declarado acima do permitido.")
    ]
  end

  def json(body, status: 200)
    { status: status, body: body.to_json, headers: { "Content-Type" => "application/json" } }
  end
end
