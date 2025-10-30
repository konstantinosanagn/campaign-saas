require "httparty"
require "json"
require "date"
require "uri"
require_relative 'spam_classifier_wrapper'

##
# CritiqueAgent integrates with the Gemini API to read through the email (title,
# email content, and number of revisions) and provide a 150-word-max critique of the email.
# @return The 150-word-max critique of the email in HTML format, in the format
# of json output

class CritiqueAgent
  include HTTParty
  base_uri "https://generativelanguage.googleapis.com/v1beta"

  # Initialize the CritiqueAgent with API key and model, as well as a
  # spam classifier instance
  def initialize(api_key: ENV['GEMINI_API_KEY'], model: 'gemini-2.5-flash')
    @api_key = api_key
    @model = model
    @headers = { "Content-Type" => "application/json" }
    @spam_classifier = SpamClassifierWrapper.new
  end

  # Provide critique for the given article (title, email content, and number of
  # revisions)
  def critique(article)
    email_content = article["email_content"].to_s
    spam_score = begin
      @spam_classifier.classify(email_content)
    rescue StandardError => e
      warn "Spam classifier error: #{e.class}: #{e.message}"
      nil
    end

    begin  
      shared_user_content = <<~PROMPT
      Today's date is #{Date.today.strftime("%d/%m/%Y")}.
      Email content:
      #{email_content}

      Your task is to provide short feedback on the email only if necessary.
      If you think the email is good, please return exactly "None".
      If you noticed the field 'message' in the article, it means the writer has revised the article based on your previous critique. You can provide feedback on the revised email or just return None if you think the email is good.
      Please return a string of your critique or None.
      PROMPT
      if spam_score.nil? || spam_score <= 0.15
        # The email is not likely to be marked as spam. We can provide instructions
        # that focus on critique.
        nonspam_system_content = <<~PROMPT
        You are a marketing email writing critique.
        Your sole purpose is to provide feedback on a written article so the writer will know what to fix to increase the chances of their target reader interacting with the email.
        Write less than 150 words, and add new line tagging so the text would be styled for HTML.
        PROMPT
        response = self.class.post(
            "/models/#{@model}:generateContent?key=#{@api_key}",
            headers: @headers,
            body: {
            contents: [
                { role: "model", parts: [{ text: nonspam_system_content }] },
                { role: "user", parts: [{ text: shared_user_content }] }
            ]
            }.to_json
        )
      else
        spam_percentage = (spam_score * 100).round(2)
        # The email is likely to be marked as spam. We can provide instructions
        # specific to decreasing spam likelihood of the email as well as critique.
        spam_system_content = <<~PROMPT
        You are a marketing email writing critique. Your sole purpose is to provide feedback on a written article so the writer will know what to fix to increase the chances of their target reader interacting with the email. 
        Additionally, the likelihood of this email being classified as spam is #{spam_percentage}%, make additional recommendations to the writer to reduce this likelihood to under 10%.
        Write less than 150 words, and add new line tagging so the text would be styled for HTML.
        PROMPT
        response = self.class.post(
            "/models/#{@model}:generateContent?key=#{@api_key}",
            headers: @headers,
            body: {
            contents: [
                { role: "model", parts: [{ text: spam_system_content }] },
                { role: "user", parts: [{ text: shared_user_content }] }
            ]
            }.to_json
        )
      end
    rescue StandardError => e
      warn "CritiqueAgent network error: #{e.class}: #{e.message}"
      return { "critique" => nil, "error" => "Network error", "detail" => e.message }
    end

    parsed = response.parsed_response
    text = parsed.dig("candidates", 0, "content", "parts", 0, "text").to_s.strip

    number_of_revisions = article["number_of_revisions"] || article[:number_of_revisions]

    # If the number of revision is 1 (AKA the email has been revised before
    # based on critique), we decide to provide no further critique to avoid 
    # infinitely calling the critique agents. Also, if the critique is "None",
    # we return nil critique.
    if text.casecmp("none").zero? || number_of_revisions.to_s == "1"
      return { "critique" => nil }
    end
    if text.empty?
      { "critique" => nil }
    else
      { "critique" => text }
    end
  end

  def run(article)
    article.merge!(critique(article))
    article
  end
end


