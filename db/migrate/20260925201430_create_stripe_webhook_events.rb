class CreateStripeWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :stripe_webhook_events do |t|
      t.string :stripe_event_id, null: false
      t.string :event_type, null: false
      t.datetime :processed_at

      t.timestamps
    end

    # Stripe delivers webhooks at least once, so the same event id can arrive
    # more than once — including concurrently. This unique index is what makes
    # "process each Stripe event exactly once" a database guarantee rather than
    # a check-then-act race.
    add_index :stripe_webhook_events, :stripe_event_id, unique: true
  end
end
