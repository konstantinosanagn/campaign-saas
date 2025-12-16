require "httparty"
require "json"
require "date"
require "uri"
require_relative "api_error"

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

    # Centralized error type classification to prevent drift across code paths
    # @param code [Integer] HTTP status code or error code
    # @return [String] Error type classification
    def self.classify_error_type(code)
      return "quota" if code == 429
      return "auth" if [ 401, 403 ].include?(code)
      return "timeout" if code == 408
      return "provider_5xx" if code >= 500 && code <= 599
      return "provider_4xx" if code >= 400 && code <= 499
      "provider_error"
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
      # Note: min_score_for_send is filtered out by PromptSettingsFilter before reaching here
      # The executor will use locked_run.min_score for meets_min_score calculation
      # We default to 6 here only for internal agent logic (should_rewrite? check)
      min_score_raw = (settings["min_score_for_send"] || settings[:min_score_for_send] || 6).to_i
      min_score = min_score_raw  # No cap - allow 0-10, executor handles the actual threshold
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

      You MUST respond in the following format:

      - First line: "Score: X/10" where X is an integer from 1 to 10.
      - Second line:
        - If the email is strong and requires no improvement, write exactly: "None"
        - Otherwise, provide constructive, actionable feedback (under 150 words) explaining how to improve the email. Write professionally and concisely, focusing on what can be changed.

      Strictness Level: #{strictness_guidance}

      IMPORTANT:
      - You are ONLY evaluating quality.
      - Do NOT adjust your scoring to meet any target. Score honestly based solely on the rubric.
      - Most real emails score 5–8. Reserve 9–10 for exceptional drafts.

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
        # Network errors are generally retryable
        # Return consistent error structure matching exception path with debug bundle
        return {
          "critique" => nil,
          "error" => "Network error",
          "detail" => e.message,
          "retryable" => true,
          "error_type" => "network",
          "error_code" => nil,
          "provider_error" => "#{e.class.name}: #{e.message}".truncate(500),
          "provider" => "gemini",
          "request_id" => nil,
          "occurred_at" => Time.now.utc.iso8601
        }
      end

      # Check HTTP response status code first
      # HTTParty's response.code returns the real HTTP status code from the server
      # This is the authoritative source, not inferred from JSON
      # Normalize to Integer and handle edge cases
      http_status = normalize_status(response)
      parsed = response.respond_to?(:parsed_response) ? response.parsed_response : nil
      body = response.respond_to?(:body) ? response.body.to_s : response.to_s

      # Capture raw response for troubleshooting (provider_error)
      # Store first 500 chars of parsed response or raw body, then sanitize
      provider_error = nil
      if parsed
        provider_error = parsed.is_a?(String) ? parsed[0..500] : parsed.to_json[0..500]
      elsif body.present?
        provider_error = body[0..500]
      end

      # Sanitize provider_error: strip newlines, redact API keys and Bearer tokens
      # IMPORTANT: Truncate AFTER all sanitization steps to ensure stored string is always <= 500 chars
      # even after replacements (e.g., "[REDACTED]" may be longer than original token)
      if provider_error
        provider_error = sanitize_provider_error(provider_error)
      end

      # ✅ raise on API-style errors (including non-JSON bodies)
      detect_and_raise_api_error!(response, http_status, body, provider_error, parsed)

      # Extract request_id from response headers or body if available
      # Use case-insensitive header lookup to handle HTTP library variations
      request_id = nil
      if response.respond_to?(:headers)
        headers = response.headers
        # Normalize headers to lowercase for case-insensitive lookup
        headers_lower = headers.is_a?(Hash) ? headers.transform_keys(&:to_s).transform_keys(&:downcase) : {}
        request_id = headers_lower["x-goog-request-id"] || headers_lower["x-request-id"] ||
                     headers["x-goog-request-id"] || headers["x-request-id"] ||
                     headers[:x_goog_request_id] || headers[:x_request_id]
      end
      # Also check parsed body for request_id
      if request_id.nil? && parsed.is_a?(Hash)
        request_id = parsed["request_id"] || parsed[:request_id] || parsed.dig("error", "request_id") || parsed.dig(:error, :request_id)
      end

      # Validate response structure
      # Allow malformed responses to return nil critique with fallback score (for graceful degradation)
      unless parsed && parsed["candidates"] && parsed["candidates"][0]
        log("CritiqueAgent: Received invalid response structure from LLM, returning nil critique with fallback score")
        number_of_revisions = article["number_of_revisions"] || article[:number_of_revisions]
        revision_count = number_of_revisions.to_i
        fallback_score = 6
        meets_min_score = fallback_score >= (article["min_score"] || article[:min_score] || 6).to_i
        return { "critique" => nil, "score" => fallback_score, "meets_min_score" => meets_min_score }
      end

      text = parsed.dig("candidates", 0, "content", "parts", 0, "text").to_s.strip

      # Log raw LLM response for debugging (dev-only, truncated to avoid log spam)
      if defined?(Rails) && Rails.env.development?
        log("Raw LLM response (first 2000 chars): #{text[0..2000]}")
      end

      # Validate that we got a meaningful response
      # Allow empty responses to return nil critique with fallback score (for graceful degradation)
      if text.nil? || text.empty?
        log("CritiqueAgent: Received empty response from LLM, returning nil critique with fallback score")
        number_of_revisions = article["number_of_revisions"] || article[:number_of_revisions]
        revision_count = number_of_revisions.to_i
        fallback_score = 6
        meets_min_score = fallback_score >= (article["min_score"] || article[:min_score] || 6).to_i
        return { "critique" => nil, "score" => fallback_score, "meets_min_score" => meets_min_score }
      end

      number_of_revisions = article["number_of_revisions"] || article[:number_of_revisions]
      revision_count = number_of_revisions.to_i

      # Extract the feedback portion (everything after the score line) first to check format
      feedback_text = extract_feedback_text(text)
      is_none_response = feedback_text.casecmp("none").zero?

      # Extract score from critique if present (look for patterns like "Score: 7/10" or "7/10")
      # Use fixed fallback_score=6 (not tied to threshold) to avoid bias
      score = extract_score_from_critique(text)

      # If the feedback is "None", use fallback score (allows graceful completion without explicit score)
      if is_none_response && score.nil?
        log("CritiqueAgent: 'None' response without explicit score, using fallback score")
        score = 6
      end

      # If score is nil (and not "None" response), retry with stricter prompt
      # Skip retry if we've reached max revisions (allow graceful exit)
      if score.nil? && !is_none_response && revision_count < 3
        log("CritiqueAgent: LLM response missing score, retrying with stricter prompt")
        score = retry_with_stricter_prompt(email_content, model_content, strictness_guidance, checks_list)

        # If retry also failed, raise error
        if score.nil?
          error_msg = "CritiqueAgent failed to extract score after retry. LLM did not provide required 'Score: X/10' format."
          log("ERROR: #{error_msg}")
          raise StandardError, error_msg
        end
      elsif score.nil? && !is_none_response && revision_count >= 3
        # Max revisions reached - use fallback score to allow graceful completion
        log("CritiqueAgent: Max revisions reached with nil score, using fallback score")
        score = 6
      end

      # Validate score is in expected range (1-10)
      unless score.is_a?(Integer) && score >= 1 && score <= 10
        error_msg = "CritiqueAgent extracted invalid score: #{score.inspect}. Expected integer 1-10."
        log("ERROR: #{error_msg}")
        raise StandardError, error_msg
      end

      # If the number of revisions reaches the max allowed attempts (3) we stop critiquing
      # to avoid infinite loops. Also, if the feedback is "None", we return nil critique
      # but KEEP the computed score.
      if feedback_text.casecmp("none").zero? || revision_count >= 3
        meets_min_score = score >= min_score
        return { "critique" => nil, "score" => score, "meets_min_score" => meets_min_score }
      end

      # Check if email meets minimum score requirement
      meets_min_score = score >= min_score

      rewrite_applied = should_rewrite?(rewrite_policy, meets_min_score, feedback_text)
      log("Rewrite triggered (policy=#{rewrite_policy}, meets_min=#{meets_min_score})") if rewrite_applied
      rewritten_email = rewrite_applied ? rewrite_email(email_content, feedback_text, settings) : nil

      base_response =
        if feedback_text.empty?
          { "critique" => nil, "score" => score, "meets_min_score" => meets_min_score }
        else
          { "critique" => feedback_text, "score" => score, "meets_min_score" => meets_min_score }
        end

      base_response["rewritten_email"] = rewritten_email if rewritten_email.present?
      base_response["rewrite_applied"] = rewrite_applied if rewrite_applied
      base_response
    end

    def run(article, config: nil)
      result = critique(article, config: config)
      article.merge!(result)
      article
    end

    private

    # Detects API errors (including plain text/HTML responses) and raises with retryable metadata
    def detect_and_raise_api_error!(response, http_status, body, provider_error, parsed)
      body_str = body.to_s
      provider_error = sanitize_provider_error(provider_error)[0, 500] if provider_error

      # Check for JSON error responses first
      if parsed.is_a?(Hash)
        error_detail = parsed["error"] || parsed[:error]
        if error_detail
          json_error_code = error_detail["code"] || error_detail[:code] || error_detail["status"] || error_detail[:status]
          error_code = http_status || (json_error_code.to_i if json_error_code)
          error_type = CritiqueAgent.classify_error_type(error_code)
          retryable = [429, 500, 502, 503, 504].include?(error_code) if error_code

          raise Agents::ApiError.new(
            "Gemini API error",
            retryable: retryable || false,
            error_code: error_code,
            error_type: error_type,
            provider_error: provider_error
          )
        end
      end

      # Check for quota errors (even if http_status is nil, body may indicate quota)
      if quota_error?(body_str, http_status)
        raise Agents::ApiError.new(
          "Gemini quota error",
          retryable: true,
          error_code: http_status || 429,
          error_type: "quota",
          provider_error: provider_error
        )
      end

      # If http_status is nil or < 400, no error to raise
      return if http_status.nil? || http_status < 400

      if http_status >= 500
        raise Agents::ApiError.new(
          "Gemini provider error",
          retryable: true,
          error_code: http_status,
          error_type: "provider_5xx",
          provider_error: provider_error
        )
      end

      if [401, 403].include?(http_status)
        raise Agents::ApiError.new(
          "Gemini auth error",
          retryable: false,
          error_code: http_status,
          error_type: "auth",
          provider_error: provider_error
        )
      end

      raise Agents::ApiError.new(
        "Gemini API error",
        retryable: false,
        error_code: http_status,
        error_type: "provider_4xx",
        provider_error: provider_error
      )
    end

    def quota_error?(body, http_status)
      http_status == 429 || body.to_s.match?(/quota|rate limit|too many requests/i)
    end

    def normalize_status(response)
      code =
        if response.respond_to?(:code)
          response.code
        elsif response.respond_to?(:response) && response.response.respond_to?(:code)
          response.response.code
        end

      code = code.to_i if code.respond_to?(:to_i)
      return nil if code.nil? || code == 0
      code
    rescue
      nil
    end

    def sanitize_provider_error(text)
      return "" if text.nil?
      text
        .gsub(/Bearer\s+[A-Za-z0-9\-\._~\+\/]+=*/i, "Bearer [REDACTED]")
        .gsub(/AIza[0-9A-Za-z\-_]{20,}/, "[REDACTED_API_KEY]")
        .gsub(/\n+/, " ")
        .strip
    end

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
          meets_min_score: critique_result["meets_min_score"] || false,
          rewritten_email: critique_result["rewritten_email"],
          rewrite_applied: critique_result["rewrite_applied"]
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

      log("Selected critique variant index=#{selected[:variant_index]} score=#{selected[:score]}")

      rewrite_needed = should_rewrite?(rewrite_policy, selected[:meets_min_score], selected[:critique].to_s)
      rewritten_email = selected[:rewritten_email] || (rewrite_needed ? rewrite_email(selected[:variant], selected[:critique], config&.dig("settings") || config&.dig(:settings) || {}) : nil)

      {
        "critique" => selected[:critique],
        "score" => selected[:score],
        "meets_min_score" => selected[:meets_min_score],
        "selected_variant_index" => selected[:variant_index],
        "selected_variant" => selected[:variant],
        "all_variants_critiques" => critiques,
        "rewritten_email" => rewritten_email,
        "rewrite_applied" => rewrite_needed && rewritten_email.present?
      }
    end

    # Extracts a score from critique text (looks for patterns like "Score: 7/10" or "7/10")
    # @param critique_text [String] The full critique text from LLM
    # @param fallback_score [Integer] Score to return if parsing fails (default: 6, not tied to threshold)
    # @return [Integer, nil] Parsed score (1-10) or nil if "None" response without explicit score
    def extract_score_from_critique(critique_text, fallback_score = 6)
      return fallback_score if critique_text.nil? || critique_text.empty?

      # Try to parse an explicit numeric score if the model gives one
      score_match = critique_text.match(/(?:score|rating|quality)[:\s]*(\d+)\s*\/?\s*10/i)
      return score_match[1].to_i.clamp(1, 10) if score_match

      # If critique is exactly "None", check if we have an explicit score
      # If no score found, return nil (don't invent a threshold-based score)
      feedback = extract_feedback_text(critique_text)
      if feedback.casecmp("none").zero?
        # Model said "None" but didn't include score - this is invalid output
        return nil
      end

      # Fallback heuristic:
      # - If there's some critique text, assume slightly below fallback
      # - If it's empty (shouldn't normally happen here), just return fallback_score
      feedback.strip.empty? ? fallback_score : (fallback_score - 1).clamp(1, 10)
    end

    # Extracts the feedback portion of the critique (everything after the score line)
    def extract_feedback_text(full_text)
      return "" if full_text.nil? || full_text.empty?

      # Split by newlines and skip lines that look like score lines
      lines = full_text.split("\n").map(&:strip)

      # Find lines that aren't score lines
      feedback_lines = lines.reject do |line|
        line.match?(/^(?:score|rating|quality)[:\s]*\d+\s*\/?\s*10/i)
      end

      feedback_lines.join("\n").strip
    end

    # Retries critique with a stricter prompt that explicitly requires "Score: X/10" format
    # @param email_content [String] The email content to critique
    # @param original_model_content [String] The original prompt (for context)
    # @param strictness_guidance [String] The strictness guidance text
    # @param checks_list [Array<String>] List of focus areas
    # @return [Integer, nil] Parsed score or nil if still missing
    def retry_with_stricter_prompt(email_content, original_model_content, strictness_guidance, checks_list)
      retry_model_content = <<~PROMPT
      #{original_model_content}

      CRITICAL: You MUST include "Score: X/10" on the first line of your response, where X is an integer from 1 to 10.
      This is a required format - do not omit the score line.
      PROMPT

      begin
        retry_response = self.class.post(
          "/models/#{@model}:generateContent?key=#{@api_key}",
          headers: @headers,
          body: {
            contents: [
              { role: "model", parts: [ { text: retry_model_content } ] },
              { role: "user", parts: [ { text: email_content } ] }
            ]
          }.to_json
        )

        retry_parsed = retry_response.parsed_response
        unless retry_parsed && retry_parsed["candidates"] && retry_parsed["candidates"][0]
          log("ERROR: Retry response has invalid structure")
          return nil
        end

        retry_text = retry_parsed.dig("candidates", 0, "content", "parts", 0, "text").to_s.strip
        return nil if retry_text.nil? || retry_text.empty?

        # Try to extract score from retry response
        extract_score_from_critique(retry_text)
      rescue StandardError => e
        log("ERROR: Retry failed: #{e.class}: #{e.message}")
        nil
      end
    end

    def should_rewrite?(policy, meets_min_score, critique_text)
      return false if critique_text.blank?

      case policy
      when "never", "none"
        false
      when "always"
        true
      else # "rewrite_if_bad"
        !meets_min_score
      end
    end

    def rewrite_email(email_content, critique_text, settings)
      prompt = <<~PROMPT
        You are an elite B2B copywriter. Rewrite the following email to address every point in the critique summary.

        Critique Feedback:
        #{critique_text}

        Original Email:
        #{email_content}

        Requirements:
        - Keep it concise, professional, and human sounding.
        - Honor any tone/persona guidance if provided (#{settings["tone"] || settings[:tone] || "professional"} tone, #{settings["sender_persona"] || settings[:sender_persona] || "founder"} persona).
        - Preserve factual claims but improve clarity, personalization, and CTA strength.
        - Return only the revised email text (subject + body). Do not include commentary.
      PROMPT

      response = self.class.post(
        "/models/#{@model}:generateContent?key=#{@api_key}",
        headers: @headers,
        body: {
          contents: [
            { role: "user", parts: [ { text: prompt } ] }
          ],
          generationConfig: {
            temperature: 0.6,
            maxOutputTokens: 2048
          }
        }.to_json
      )

      rewritten = response.parsed_response.dig("candidates", 0, "content", "parts", 0, "text").to_s.strip
      log("Rewrite completed (length=#{rewritten.length})")
      rewritten
    rescue StandardError => e
      log("Rewrite error: #{e.class}: #{e.message}")
      nil
    end

    def log(message)
      formatted = "[CritiqueAgent] #{message}"
      if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
        Rails.logger.info(formatted)
      else
        puts(formatted)
      end
    end
  end
end
