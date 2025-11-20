class LeadMailer < ApplicationMailer
  # Dynamically set sender based on params
  default from: -> { params[:from] }

  def outreach_email
    @html_body = params[:body]

    mail(
      to: params[:to],
      subject: params[:subject]
    ) do |format|
      format.html { render html: @html_body.to_s.html_safe }
    end
  end
end
