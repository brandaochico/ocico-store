# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"

RSpec.describe RefundMailer do
  let!(:store) { create(:store, name: "ocico store", mail_from_address: "pedidos@ocico.store") }
  let(:order) { create(:completed_order_with_totals, store:) }
  let!(:payment) { create(:payment, order:, state: "completed", amount: order.total) }

  def refund_of(amount)
    Spree::Refund.create!(payment:, amount:, reason: create(:refund_reason), transaction_id: "re_#{amount}")
  end

  it "tells the customer the whole order was refunded" do
    mail = described_class.refund_email(refund_of(order.total))

    expect(mail.to).to eq([ order.email ])
    expect(mail.subject).to eq("Reembolso do pedido ##{order.number}")
    expect(mail.text_part.body.to_s).to include("Reembolsamos o valor do seu pedido ##{order.number}")
    expect(mail.text_part.body.to_s).not_to include("Total reembolsado")
  end

  it "says how much of the order a partial refund covers" do
    mail = described_class.refund_email(refund_of(5))

    expect(mail.text_part.body.to_s).to include("Reembolsamos R$5,00 do seu pedido", "Total reembolsado neste pedido até agora")
  end

  it "links an account's order plainly — it opens after logging in" do
    mail = described_class.refund_email(refund_of(5))

    expect(mail.text_part.body.to_s).to include("/orders/#{order.number}")
    expect(mail.text_part.body.to_s).not_to include("/token/")
  end

  it "links a guest's order with its token, the only way a guest can open it" do
    order.update_columns(user_id: nil)

    mail = described_class.refund_email(refund_of(5))

    expect(mail.text_part.body.to_s).to include("/orders/#{order.number}/token/#{order.guest_token}")
  end

  it "comes from the store, with replies going to the store's inbox" do
    mail = described_class.refund_email(refund_of(5))

    expect(mail[:from].to_s).to eq("ocico store <pedidos@ocico.store>")
    expect(mail.reply_to).to eq([ "contato@ocico.store" ])
  end
end
