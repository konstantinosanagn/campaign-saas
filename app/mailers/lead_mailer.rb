class LeadMailer < ApplicationMailer
  include MarkdownHelper
  # Dynamically set sender based on params
  default from: -> { params[:from] }

  def outreach_email
    markdown = params[:body].to_s

    mail(to: params[:to], subject: params[:subject]) do |format|
      format.html { render html: markdown_to_html(markdown) }
      format.text { render plain: markdown_to_text(markdown) }
    end
  end
end
