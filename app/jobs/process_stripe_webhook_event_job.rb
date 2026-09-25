# frozen_string_literal: true

# Processes one Stripe webhook event, off the request cycle.
#
# solidus_stripe's own controller publishes to Spree::Bus inline, which means
# the payment state transition (capture, fail, void, refund sync) happens while
# Stripe waits for the HTTP response. If that response is slow or times out,
# Stripe retries and the whole transition runs a second time. We acknowledge
# immediately instead and do the work here — see the webhook override in
# app/overrides/stripe_webhooks_async_processing.rb.
#
# The event is re-published to Spree::Bus from inside the job, so
# solidus_stripe's own subscribers keep handling it unchanged; the only thing
# that moves is *when* they run.
class ProcessStripeWebhookEventJob < ApplicationJob
  queue_as :critical

  # Nothing here is worth processing if the payment method has since been
  # deleted — the event can't be attributed to anything.
  discard_on ActiveJob::DeserializationError

  def perform(payload)
    stripe_event = payload.fetch("stripe_event")

    record = StripeWebhookEvent.claim(
      stripe_event_id: stripe_event.fetch("id"),
      event_type: stripe_event.fetch("type")
    )

    # The lock serializes concurrent deliveries of the same event; the
    # processed? check inside it stops the second one from doing the work
    # again. A job that raises leaves processed_at unset, so an Active Job
    # retry still gets to run.
    record.with_lock do
      next if record.processed?

      Spree::Bus.publish(build_event(payload))
      record.mark_processed!
    end
  end

  private

  def build_event(payload)
    SolidusStripe::Webhook::Event.new(
      stripe_event: Stripe::Event.construct_from(payload.fetch("stripe_event").deep_symbolize_keys),
      payment_method: SolidusStripe::PaymentMethod.find(payload.fetch("payment_method_id"))
    )
  end
end
