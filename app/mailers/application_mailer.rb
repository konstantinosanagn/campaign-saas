class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "campaignsaastester@gmail.com")
  layout "mailer"
end
