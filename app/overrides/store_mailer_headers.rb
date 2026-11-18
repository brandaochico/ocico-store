# frozen_string_literal: true

# How every store email (Solidus' order/shipment/reimbursement mailers and
# UserMailer) presents itself in the customer's inbox.
#
# - From: the store's mail_from_address (pedidos@ocico.store, a send-only
#   Brevo address) is a bare address — that's what the admin field holds — so
#   the store name is added as the display name. Brevo doesn't apply the name
#   set in its dashboard to SMTP mail; without this, inboxes show "pedidos".
# - Reply-To: pedidos@ has no mailbox, so replies go to contato@ocico.store,
#   the inbox that is actually read (Hostinger).
#
# The address is a method rather than a constant: app/overrides is loaded
# twice (Zeitwerk and deface's loader), and a constant would warn "already
# initialized".
module StoreMailerHeaders
  def self.reply_to_address
    "ocico store <contato@ocico.store>"
  end

  def self.prepended(base)
    base.default reply_to: reply_to_address
  end

  def from_address(store)
    address = super
    return address if address.blank? || address.include?("<")

    email_address_with_name(address, store.name)
  end

  ::Spree::BaseMailer.prepend self
end
