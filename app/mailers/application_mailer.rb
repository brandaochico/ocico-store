class ApplicationMailer < ActionMailer::Base
  default from: "ocico store <pedidos@ocico.store>", reply_to: MailerReplyTo.address
  layout "mailer"
end
