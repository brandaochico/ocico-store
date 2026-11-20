# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"

# A refunded order must not look like a confirmed (or an unpaid) one.
RSpec.describe "A refunded order", type: :request do
  let!(:store) { create(:store) }
  let(:user) { create(:user) }
  let(:order) { create(:completed_order_with_totals, user:, store:) }
  let!(:payment) { create(:payment, order:, state: "completed", amount: order.total) }

  before do
    order.recalculate
    sign_in(user)
  end

  def refund(amount)
    Spree::Refund.create!(payment:, amount:, reason: create(:refund_reason), transaction_id: "re_#{amount}")
    order.recalculate
  end

  it "says so in the order page's title and explains it" do
    refund(order.total)

    get order_path(order)

    expect(response.body).to include("Reembolsado", "Este pedido foi reembolsado")
    expect(response.body).not_to include("- Confirmado")
  end

  it "tells a partial refund apart" do
    refund(5)

    get order_path(order)

    expect(response.body).to include("Reembolso parcial", "Reembolsamos R$5,00 deste pedido")
  end

  it "shows nothing about refunds on an order that wasn't refunded" do
    get order_path(order)

    expect(response.body).not_to include("Reembolsado", "Reembolso parcial")
  end

  it "badges the order in the account's order list" do
    refund(order.total)

    get account_path

    expect(response.body).to include("badge-refunded", "Reembolsado")
  end
end
