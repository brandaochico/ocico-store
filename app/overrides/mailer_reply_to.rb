# frozen_string_literal: true

# Store email is sent from pedidos@ocico.store, a send-only address (Brevo)
# with no mailbox behind it. Replies go to contato@ocico.store, the inbox that
# is actually read (Hostinger). The sender itself is the store's
# mail_from_address (db/seeds/catalog.rb), which Solidus' mailers pass as
# `from:`; this only adds the Reply-To they don't set.
#
# A method rather than a constant: app/overrides is loaded twice (Zeitwerk and
# deface's loader), and a constant would warn "already initialized".
module MailerReplyTo
  def self.address
    "ocico store <contato@ocico.store>"
  end

  def self.prepended(base)
    base.default reply_to: address
  end

  ::Spree::BaseMailer.prepend self
end
