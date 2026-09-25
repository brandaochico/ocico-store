# frozen_string_literal: true

# Makes Stripe webhook handling asynchronous.
#
# Upstream's SolidusStripe::WebhooksController#create verifies the signature
# and then publishes to Spree::Bus inline, so the payment state transition runs
# while Stripe waits on the HTTP response. A slow or timed-out response makes
# Stripe redeliver the event and run that transition again.
#
# This replaces the publish with an enqueue: signature verification stays in
# the request (an unverifiable event must still be rejected with a 400, and
# Stripe's signature tolerance is measured against delivery time, not against
# whenever a worker gets to it), and everything that writes happens in
# ProcessStripeWebhookEventJob.
module StripeWebhooksAsyncProcessing
  def create
    event = ::SolidusStripe::Webhook::Event.from_request(
      payload: request.body.read,
      signature_header: signature_header,
      slug: params[:slug]
    )
    return head(:bad_request) unless event

    ProcessStripeWebhookEventJob.perform_later(event.payload)
    head(:ok)
  end

  ::SolidusStripe::WebhooksController.prepend self
end
