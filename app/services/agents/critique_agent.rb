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
    # @param article [Hash] Contains email_content, variants (optional), and number_of_revisions
    # @param config [Hash, nil] Agent configuration with settings
    def critique(article, config: nil)
      # Get settings from config or use defaults
      settings = config&.dig("settings") || config&.dig(:settings) || {}
      checks = settings["checks"] || settings[:checks] || {}
      check_personalization = checks["check_personalization"] != false # Default true
      check_brand_voice = checks["check_brand_voice"] != false # Default true
      check_spamminess = checks["check_spamminess"] != false # Default true
      strictness = settings["strictness"] || settings[:strictness] || "moderate"
      min_score = (settings["min_score_for_send"] || settings[:min_score_for_send] || 6).to_i
      rewrite_policy = settings["rewrite_policy"] || settings[:rewrite_policy] || "rewrite_if_bad"
      variant_selection = settings["variant_selection"] || settings[:variant_selection] || "highest_overall_score"

      # Handle variants if present
      variants = article["variants"] || article[:variants] || []
      email_content = article["email_content"].to_s

      # If we have variants, critique all of them and select the best one
      if variants.any? && variant_selection != "none"
        return critique_and_select_variant(variants, config, variant_selection, min_score, rewrite_policy)
      end

      begin
        # Build critique prompt based on settings
        strictness_guidance = case strictness
        when "lenient"
          "Be lenient - only flag extreme issues. Focus on major problems that would significantly impact email effectiveness."
        when "moderate"
          "Enforce basic quality & tone standards. Flag issues that would reduce email effectiveness or professionalism."
        when "strict"
          "Be strict - require strong personalization & adherence to best practices. Flag any issues that could be improved."
        else
          "Enforce basic quality & tone standards."
        end

        checks_list = []
        checks_list << "Personalization: Check if the email shows research and personalization appropriate for the recipient and company." if check_personalization
        checks_list << "Brand Voice: Verify the tone and style match the intended brand voice and persona." if check_brand_voice
        checks_list << "Spamminess: Identify spam-trigger words, excessive promotional language, or patterns that could hurt deliverability." if check_spamminess

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

      Strictness Level: #{strictness_guidance}

      Minimum Score for Send: #{min_score}/10. If the email scores below #{min_score}, provide feedback to improve it.

      #{checks_list.any? ? "Focus Areas:\n#{checks_list.map { |c| "- #{c}" }.join("\n")}\n\n" : ""}

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

      # Extract score from critique if present (look for patterns like "Score: 7/10" or "7/10")
      score = extract_score_from_critique(text, min_score)

      # If the number of revisions reaches the max allowed attempts (3) we stop critiquing
      # to avoid infinite loops. Also, if the critique is "None", we return nil critique.
      if text.casecmp("none").zero? || revision_count >= 3
        return { "critique" => nil, "score" => 10, "meets_min_score" => true }
      end

      # Check if email meets minimum score requirement
      meets_min_score = score >= min_score

      if text.empty?
        { "critique" => nil, "score" => score, "meets_min_score" => meets_min_score }
      else
        { "critique" => text, "score" => score, "meets_min_score" => meets_min_score }
      end
    end

    def run(article, config: nil)
      result = critique(article, config: config)
      article.merge!(result)
      article
    end

    private

    # Critiques all variants and selects the best one based on variant_selection
    def critique_and_select_variant(variants, config, variant_selection, min_score, rewrite_policy)
      critiques = variants.map.with_index do |variant, index|
        article = {
          "email_content" => variant,
          "number_of_revisions" => 0
        }
        critique_result = critique(article, config: config)
        {
          variant_index: index,
          variant: variant,
          critique: critique_result["critique"],
          score: critique_result["score"] || 5,
          meets_min_score: critique_result["meets_min_score"] || false
        }
      end

      # Select best variant based on variant_selection strategy
      selected = case variant_selection
      when "highest_personalization_score"
        # Find variant with highest personalization (prioritize variants with no critique or lowest critique length)
        critiques.max_by { |c| c[:score] * 2 + (c[:critique].nil? ? 10 : -c[:critique].length) }
      else # "highest_overall_score"
        # Find variant with highest overall score
        critiques.max_by { |c| c[:score] }
      end

      {
        "critique" => selected[:critique],
        "score" => selected[:score],
        "meets_min_score" => selected[:meets_min_score],
        "selected_variant_index" => selected[:variant_index],
        "selected_variant" => selected[:variant],
        "all_variants_critiques" => critiques
      }
    end

    # Extracts a score from critique text (looks for patterns like "Score: 7/10" or "7/10")
    def extract_score_from_critique(critique_text, default_score)
      return default_score if critique_text.nil? || critique_text.empty?

      # Look for score patterns
      score_match = critique_text.match(/(?:score|rating|quality)[:\s]*(\d+)\s*\/?\s*10/i)
      return score_match[1].to_i if score_match

      # If critique is "None", assume high score
      return 10 if critique_text.casecmp("none").zero?

      # Default: if critique exists, assume it needs improvement (lower score)
      # If no critique, assume it's good (higher score)
      critique_text.strip.empty? ? 8 : 5
    end
  end
end
