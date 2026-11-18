# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"

RSpec.describe StoreMailerHeaders, type: :mailer do
  let(:store) { create(:store, name: "ocico store", mail_from_address: "pedidos@ocico.store") }
  let(:order) { create(:completed_order_with_totals, store:) }

  describe "order confirmation" do
    subject(:message) { Spree::OrderMailer.confirm_email(order) }

    it "shows the store name as the sender of the bare store address" do
      expect(message.from).to eq [ "pedidos@ocico.store" ]
      expect(message[:from].display_names).to eq [ "ocico store" ]
    end

    it "sends replies to the contact inbox" do
      expect(message.reply_to).to eq [ "contato@ocico.store" ]
    end

    it "drops the store-name prefix from the subject" do
      expect(message.subject).to eq "#{I18n.t('spree.order_mailer.confirm_email.subject')} ##{order.number}"
    end

    it "keeps the resend marker" do
      resent = Spree::OrderMailer.confirm_email(order, true)

      expect(resent.subject).to eq "[#{I18n.t('spree.resend').upcase}] " \
        "#{I18n.t('spree.order_mailer.confirm_email.subject')} ##{order.number}"
    end
  end

  it "leaves an address that already has a display name alone" do
    store.update!(mail_from_address: "Outro Nome <pedidos@ocico.store>")

    expect(Spree::OrderMailer.confirm_email(order)[:from].display_names).to eq [ "Outro Nome" ]
  end
end
