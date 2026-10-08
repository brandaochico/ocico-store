# frozen_string_literal: true

namespace :mercado_pago do
  # Development runs Active Job's async adapter and no recurring jobs, so
  # nothing syncs Pix/Boleto payments by itself — and enqueueing from a
  # one-off process doesn't work either: it exits before the jobs run.
  desc "Sync every pending Pix/Boleto payment with Mercado Pago, right now"
  task sync: :environment do
    ids = MercadoPago::SyncPendingPaymentsJob.pending_mp_order_ids
    ids.each { |mp_order_id| MercadoPago::SyncPaymentJob.perform_now(mp_order_id) }
    puts "Synced #{ids.size} pending Mercado Pago order(s)." # rubocop:disable Rails/Output
  end
end
