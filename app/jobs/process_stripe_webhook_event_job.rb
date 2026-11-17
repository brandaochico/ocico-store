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

  # Stripe got its 200 when the request was verified, so it will never
  # redeliver: if the transition fails here (a Stripe API hiccup inside
  # RefundsSynchronizer, a deadlock), retrying is the only way it still
  # happens. Retries are safe — the row lock and processed? check below make
  # the transition run at most once. A job that exhausts its attempts stays in
  # Solid Queue's failed executions, with its event row unprocessed.
  retry_on StandardError, wait: :polynomially_longer, attempts: 10

  def perform(payload)
    stripe_event = payload.fetch("stripe_event")

    # Nothing here is worth processing if the payment method has since been
    # deleted — the event can't be attributed to anything, and retrying won't
    # bring it back.
    payment_method = SolidusStripe::PaymentMethod.find_by(id: payload.fetch("payment_method_id"))
    unless payment_method
      Rails.logger.warn("[Stripe] dropping #{stripe_event["type"]} #{stripe_event["id"]}: payment method is gone")
      return
    end

    record = StripeWebhookEvent.claim(
      stripe_event_id: stripe_event.fetch("id"),
      event_type: stripe_event.fetch("type")
    )

    # The lock serializes concurrent deliveries of the same event; the
    # processed? check inside it stops the second one from doing the work
    # again. A job that raises leaves processed_at unset, so the retry above
    # still gets to run.
    record.with_lock do
      next if record.processed?

      Spree::Bus.publish(build_event(stripe_event, payment_method))
      record.mark_processed!
    end
  end

  private

  def build_event(stripe_event, payment_method)
    SolidusStripe::Webhook::Event.new(
      stripe_event: Stripe::Event.construct_from(stripe_event.deep_symbolize_keys),
      payment_method: payment_method
    )
  end
end
