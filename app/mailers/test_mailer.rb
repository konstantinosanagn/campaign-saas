class TestMailer < ApplicationMailer
  def smtp_test_email
    @user = params[:to]
    mail(
      to: params[:to],
      from: params[:from],
      subject: "SMTP Test Email",
      body: "SMTP is working correctly!"
    )
  end
end
