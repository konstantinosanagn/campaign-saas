require "httparty"
require "json"
require "date"
require "uri"

module Agents
  ##
  # CritiqueAgent integrates with the Gemini API to read through the email (title,
  # email content, and number of revisions) and provide a 150-word-max critique of the email.
  # @return The 150-word-max critique of the email in HTML format, in the format
  # of json output
  class CritiqueAgent
    include HTTParty
    base_uri "https://generativelanguage.googleapis.com/v1beta"

    # Initialize the CritiqueAgent with API key and model
    def initialize(api_key:, model: "gemini-2.5-flash")
      @api_key = api_key
      @model = model
      @headers = { "Content-Type" => "application/json" }
      raise ArgumentError, "Gemini API key is required" if @api_key.blank?
    end

    # Provide critique for the given article (title, email content, and number of
    # revisions)
    def critique(article)
      email_content = article["email_content"].to_s

      begin
        model_content = <<~PROMPT
      Today's date is #{Date.today.strftime("%d/%m/%Y")}. You are the Critique Agent in a multi-agent workflow that evaluates and provides structured feedback on marketing email drafts from the user.

      Your goal is to assess the quality of an email using objective and quantitative criteria across five dimensions:

      1. Readability & Clarity

      2. Engagement & Persuasion

      3. Structural & Stylistic Quality

      4. Brand Alignment & Tone Consistency

      5. Deliverability & Technical Health

      You must output string:

      - If the email is strong and requires no improvement, return exactly: None

      - Otherwise, output constructive, actionable feedback (under 150 words) explaining how to improve the email. Write professionally and concisely, focusing on what can be changed.

      Use the following criteria for your evaluation and feedback formulation:

      1. Readability & Clarity

      - Estimate readability (Flesch Reading Ease) and grade level.

      - Check sentence length, simplicity, and passive voice.

      - Aim for clear, conversational tone (grade 6-8 level).

      2. Engagement & Persuasion

      - Assess tone and energy.

      - Evaluate quality and placement of Calls-To-Action (CTAs).

      - Reward positive sentiment and natural persuasive words.

      3. Structure & Style

      - Check logical flow: subject → body → CTA.

      - Prefer short paragraphs and clean formatting.

      4. Brand & Tone Consistency

      - Ensure tone matches intent (friendly, professional, confident, etc.).

      5. Deliverability

      - Penalize spam-trigger words or excessive links.

      - Reward clean, trustworthy, text-focused content.

      Use the critique framework described above to evaluate the following marketing email draft:
      PROMPT

        response = self.class.post(
            "/models/#{@model}:generateContent?key=#{@api_key}",
            headers: @headers,
            body: {
            contents: [
                { role: "model", parts: [ { text: model_content } ] },
                { role: "user", parts: [ { text: email_content } ] }
            ]
            }.to_json
        )
      rescue StandardError => e
        warn "CritiqueAgent network error: #{e.class}: #{e.message}"
        return { "critique" => nil, "error" => "Network error", "detail" => e.message }
      end

      parsed = response.parsed_response
      text = parsed.dig("candidates", 0, "content", "parts", 0, "text").to_s.strip

      number_of_revisions = article["number_of_revisions"] || article[:number_of_revisions]
      revision_count = number_of_revisions.to_i

      # If the number of revisions reaches the max allowed attempts (3) we stop critiquing
      # to avoid infinite loops. Also, if the critique is "None", we return nil critique.
      if text.casecmp("none").zero? || revision_count >= 3
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
end
