# frozen_string_literal: true

# One row per Stripe webhook event we've been delivered, used to make webhook
# processing idempotent.
#
# Stripe guarantees at-least-once delivery, so the same event id can arrive
# twice — and, since we acknowledge the request and process in the background,
# two deliveries can be in flight at the same time. Without this, a duplicate
# `charge.refunded` could race past RefundsSynchronizer's "is it already
# synced?" check and create the same Spree::Refund twice.
#
# See ProcessStripeWebhookEventJob, which is the only thing that writes here.
class StripeWebhookEvent < ApplicationRecord
  validates :stripe_event_id, presence: true, uniqueness: true
  validates :event_type, presence: true

  scope :processed, -> { where.not(processed_at: nil) }

  # Returns the row for this Stripe event, creating it if this is the first
  # delivery. Races on the unique index are expected, not exceptional: whoever
  # loses simply reads the row the winner just wrote.
  def self.claim(stripe_event_id:, event_type:)
    find_or_create_by!(stripe_event_id: stripe_event_id) do |event|
      event.event_type = event_type
    end
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    # Whichever of the two the loser hits depends on whether the winner's
    # INSERT landed before or after the uniqueness validation's SELECT.
    find_by!(stripe_event_id: stripe_event_id)
  end

  def processed?
    processed_at.present?
  end

  def mark_processed!
    update!(processed_at: Time.current)
  end
end
