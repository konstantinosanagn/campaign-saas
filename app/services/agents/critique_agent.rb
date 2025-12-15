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

    # Centralized error type classification to prevent drift across code paths
    # @param code [Integer] HTTP status code or error code
    # @return [String] Error type classification
    def self.classify_error_type(code)
      return "quota" if code == 429
      return "auth" if [401, 403].include?(code)
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
      http_status = response.respond_to?(:code) ? response.code.to_i : nil
      http_status = nil if http_status == 0  # Handle invalid/zero status codes
      parsed = response.respond_to?(:parsed_response) ? response.parsed_response : nil
      
      # Capture raw response for troubleshooting (provider_error)
      # Store first 500 chars of parsed response or raw body, then sanitize
      provider_error = nil
      if parsed
        provider_error = parsed.is_a?(String) ? parsed[0..500] : parsed.to_json[0..500]
      elsif response.respond_to?(:body)
        provider_error = response.body.to_s[0..500] if response.body
      end
      
      # Sanitize provider_error: strip newlines, redact API keys and Bearer tokens
      # IMPORTANT: Truncate AFTER all sanitization steps to ensure stored string is always <= 500 chars
      # even after replacements (e.g., "[REDACTED]" may be longer than original token)
      if provider_error
        provider_error = provider_error.gsub(/\n+/, " ").strip  # Strip newlines
        provider_error = provider_error.gsub(/Bearer\s+[A-Za-z0-9\-\._]+/, "Bearer [REDACTED]")  # Redact Bearer tokens
        provider_error = provider_error.gsub(/AIza[0-9A-Za-z\-_]{20,}/, "[REDACTED]")  # Redact Gemini API keys
        provider_error = provider_error.truncate(500)  # Final truncation after all sanitization
      end
      
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
      
      # Determine if this is an error response using multiple detection methods
      is_error = false
      error_code = nil
      error_message = nil
      error_type = nil
      retryable = false
      
      # Method 1: HTTP status code >= 400 (real HTTP status from HTTParty)
      # Always use HTTP status first - it's the authoritative source
      if http_status && http_status >= 400
        is_error = true
        error_code = http_status  # Use real HTTP status code (already normalized to Integer)
        retryable = [429, 500, 502, 503, 504].include?(http_status)
        
        # Classify error type based on HTTP status (consistent mapping)
        error_type = case http_status
        when 429
          "quota"
        when 401, 403
          "auth"
        when 408
          "timeout"
        when 500, 502, 503, 504
          "provider_5xx"
        else
          "provider_4xx"
        end
      end
      
      # Method 2: Check for various error response formats
      if parsed
        # Check for top-level "error" object
        if parsed["error"] || parsed[:error]
          is_error = true
          error_detail = parsed["error"] || parsed[:error]
          # Extract JSON error code, but only use if numeric and HTTP status not available
          json_error_code = error_detail["code"] || error_detail[:code] || error_detail["status"] || error_detail[:status]
          # Ensure error_code uses HTTP status first (already set above if http_status >= 400)
          # Only fall back to JSON code if it's >= 400 and HTTP status wasn't available
          if error_code.nil? && json_error_code
            code_i = json_error_code.to_i
            error_code = code_i if code_i >= 400
          end
          error_message ||= error_detail["message"] || error_detail[:message] || "Unknown API error"
          retryable ||= [429, 500, 502, 503, 504].include?(error_code) if error_code
          
          # Classify error type if not already set (driven by numeric error_code)
          unless error_type && error_code
            error_type = CritiqueAgent.classify_error_type(error_code)
          end
        end
        
        # Check for "errors" array
        if parsed["errors"] || parsed[:errors]
          is_error = true
          errors_array = parsed["errors"] || parsed[:errors]
          if errors_array.is_a?(Array) && errors_array.any?
            first_error = errors_array.first
            json_error_code = first_error["code"] || first_error[:code] || first_error["status"] || first_error[:status]
            # Ensure error_code uses HTTP status first (already set above if http_status >= 400)
            # Only fall back to JSON code if it's numeric, > 0, and HTTP status wasn't available
            if error_code.nil? && json_error_code
              json_error_code = json_error_code.to_i if json_error_code.respond_to?(:to_i)
              # After to_i, is_a?(Numeric) will be true, so > 0 is the real guard
              error_code = json_error_code if json_error_code > 0
            end
            error_message ||= first_error["message"] || first_error[:message] || "API returned errors"
            retryable ||= [429, 500, 502, 503, 504].include?(error_code) if error_code
            
            # Classify error type if not already set (driven by numeric error_code)
            unless error_type && error_code
              error_type = CritiqueAgent.classify_error_type(error_code)
            end
          end
        end
        
        # Check for status/code fields >= 400 (fallback if HTTP status not available)
        # Only use if error_code not already set from HTTP status
        status = parsed["status"] || parsed[:status]
        code = parsed["code"] || parsed[:code]
        
        # Only trigger error handling if status is actually >= 400 and error_code not already set
        # Ordering: check error_code.nil? first, then convert and check >= 400
        if status && error_code.nil?
          status_i = status.to_i
          if status_i >= 400
            is_error = true
            error_code = status_i
            retryable ||= [429, 500, 502, 503, 504].include?(error_code)
            error_type ||= CritiqueAgent.classify_error_type(error_code)
          end
        elsif code && error_code.nil?
          code_i = code.to_i
          if code_i >= 400
            is_error = true
            error_code = code_i
            retryable ||= [429, 500, 502, 503, 504].include?(error_code)
            error_type ||= CritiqueAgent.classify_error_type(error_code)
          end
        end
        
        # Method 3: Check response body for error keywords (for plain text/HTML errors)
        # Only check if we haven't already detected an error
        if !is_error
          # Handle string responses (plain text/HTML)
          if parsed.is_a?(String)
            body_lower = parsed.downcase
            if body_lower.include?("quota") || body_lower.include?("429")
              is_error = true
              # Use HTTP status if available, otherwise infer from body
              error_code ||= http_status || 429
              error_message ||= parsed[0..200] # Use first 200 chars of response
              retryable = true # Quota errors are retryable
              error_type ||= "quota"
            elsif body_lower.include?("500") || body_lower.include?("502") || 
                  body_lower.include?("503") || body_lower.include?("504")
              is_error = true
              # Use HTTP status if available, otherwise infer from body
              error_code ||= http_status || 500
              error_message ||= parsed[0..200]
              retryable = true # Server errors are retryable
              error_type ||= "provider_5xx"
            elsif (body_lower.include?("error") || body_lower.include?("failed")) && 
                  !body_lower.include?("candidates") && !body_lower.include?("content")
              # Only treat as error if it doesn't look like a valid response
              is_error = true
              # Use HTTP status if available, otherwise default to 500
              error_code ||= http_status || 500
              error_message ||= parsed[0..200]
              retryable ||= [429, 500, 502, 503, 504].include?(error_code) if error_code
              error_type ||= "provider_error"
            end
          end
        end
      end
      
      # If error detected, raise with appropriate message
      if is_error
        # Ensure error_code is set (prefer HTTP status, fallback to 500)
        error_code ||= http_status || 500
        error_message ||= "Unknown API error"
        # Ensure error_type is set (should be set above, but fallback if not)
              error_type ||= CritiqueAgent.classify_error_type(error_code)
        
        # Provide user-friendly error messages for common API errors
        user_friendly_msg = case error_code
        when 429
          "API quota exceeded. Please check your API plan and billing details, or wait before retrying."
        when 401
          "API authentication failed. Please check your API key."
        when 403
          "API access forbidden. Please check your API permissions."
        when 500, 502, 503, 504
          "API service temporarily unavailable. Please try again later."
        else
          "API error (#{error_code}): #{error_message}"
        end
        
        error_msg = "CritiqueAgent received API error from LLM: #{user_friendly_msg}"
        log("ERROR: #{error_msg}")
        
        # Raise error with retryable flag, error_code, error_type, provider_error, and debug bundle attached
        # Capture values in local variables to ensure closure works correctly
        retryable_flag = retryable
        captured_error_code = error_code
        captured_error_type = error_type
        captured_provider_error = provider_error
        captured_request_id = request_id
        error = StandardError.new(error_msg)
        error.define_singleton_method(:retryable?) { retryable_flag }
        error.define_singleton_method(:error_code) { captured_error_code }
        error.define_singleton_method(:error_type) { captured_error_type }
        error.define_singleton_method(:provider_error) { captured_provider_error }
        error.define_singleton_method(:request_id) { captured_request_id }
        error.define_singleton_method(:provider) { "gemini" }
        error.define_singleton_method(:occurred_at) { Time.now.utc.iso8601 }
        raise error
      end

      # Validate response structure
      unless parsed && parsed["candidates"] && parsed["candidates"][0]
        # Sanitize parsed response before logging (may contain sensitive data)
        # Make it crash-proof: handle to_json failures gracefully
        raw = parsed.is_a?(String) ? parsed : (parsed.to_json rescue parsed.inspect)
        sanitized = raw.to_s[0..200]
        sanitized = sanitized.gsub(/Bearer\s+[A-Za-z0-9\-\._]+/, "Bearer [REDACTED]")
        sanitized = sanitized.gsub(/AIza[0-9A-Za-z\-_]{20,}/, "[REDACTED]")
        error_msg = "CritiqueAgent received invalid response structure from LLM: #{sanitized}"
        log("ERROR: #{error_msg}")
        raise StandardError, error_msg
      end

      text = parsed.dig("candidates", 0, "content", "parts", 0, "text").to_s.strip

      # Log raw LLM response for debugging (dev-only, truncated to avoid log spam)
      if defined?(Rails) && Rails.env.development?
        log("Raw LLM response (first 2000 chars): #{text[0..2000]}")
      end

      # Validate that we got a meaningful response
      if text.nil? || text.empty?
        error_msg = "CritiqueAgent received empty response from LLM"
        log("ERROR: #{error_msg}")
        raise StandardError, error_msg
      end

      number_of_revisions = article["number_of_revisions"] || article[:number_of_revisions]
      revision_count = number_of_revisions.to_i

      # Extract the feedback portion (everything after the score line) first to check format
      feedback_text = extract_feedback_text(text)
      is_none_response = feedback_text.casecmp("none").zero?

      # Extract score from critique if present (look for patterns like "Score: 7/10" or "7/10")
      # Use fixed fallback_score=6 (not tied to threshold) to avoid bias
      score = extract_score_from_critique(text)

      # If score is nil (e.g., "None" response without explicit score), retry with stricter prompt
      # Skip retry if we've reached max revisions (allow graceful exit)
      if score.nil? && revision_count < 3
        log("CritiqueAgent: LLM response missing score, retrying with stricter prompt")
        score = retry_with_stricter_prompt(email_content, model_content, strictness_guidance, checks_list)
        
        # If retry also failed, raise error
        if score.nil?
          error_msg = "CritiqueAgent failed to extract score after retry. LLM did not provide required 'Score: X/10' format."
          log("ERROR: #{error_msg}")
          raise StandardError, error_msg
        end
      elsif score.nil? && revision_count >= 3
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
