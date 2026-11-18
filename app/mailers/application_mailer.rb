class ApplicationMailer < ActionMailer::Base
  default from: "ocico store <pedidos@ocico.store>", reply_to: StoreMailerHeaders.reply_to_address
  layout "mailer"
end
