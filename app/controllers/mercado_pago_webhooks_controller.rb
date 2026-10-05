# frozen_string_literal: true

# Receives Mercado Pago Orders API notifications.
#
# Verifies the signature and enqueues; nothing that writes happens in the
# request (same split as app/overrides/stripe_webhooks_async_processing.rb).
# The job then reads the order's status from the API itself rather than
# trusting this body.
class MercadoPagoWebhooksController < ActionController::API
  def create
    data_id = request.query_parameters["data.id"].presence || params.dig(:data, :id)

    signed = MercadoPago::WebhookSignature.valid?(
      x_signature: request.headers["x-signature"],
      x_request_id: request.headers["x-request-id"],
      data_id: data_id,
      secret: Rails.configuration.x.mercado_pago[:webhook_secret]
    )
    return head(:unauthorized) unless signed

    type = request.request_parameters["type"].presence || request.query_parameters["type"]
    MercadoPago::SyncPaymentJob.perform_later(data_id) if type == "order" && data_id.present?

    # Acknowledged even when ignored, or Mercado Pago keeps redelivering it.
    head(:ok)
  end
end
