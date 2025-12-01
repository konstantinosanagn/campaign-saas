require "httparty"
require "json"

=begin
WRITER AGENT

OVERVIEW:
The WriterAgent uses Google's Gemini AI to generate personalized, contextually-aware B2B marketing emails
for target companies. It transforms research data from SearchAgent into compelling, human-like outreach emails.

HOW IT WORKS:
1. Receives search results from SearchAgent containing company news
2. Receives target company name (and optional recipient name)
3. Builds a comprehensive prompt that includes:
   - Research sources (title, URL, content) obtained from SearchAgent
   - Company name and recipient information
   - B2B email best practices (subject line, CTA, tone, spam prevention)
   - Specific formatting requirements
4. Calls Gemini API to generate email
5. Returns email with subject line and body

INPUT:
search_results:
  {
    company: "Microsoft",
    sources: [{title: "...", url: "...", content: "..."}, ...],
    image: "https://..."
  }
recipient: "John Doe" (optional)
company: "Microsoft"

OUTPUT:
{
  company: "Microsoft",
  email: "Subject: ...\n\nHi John,\n...",
  recipient: "John Doe",
  sources: [...],
  image: "..."
}

KEY FEATURES:
- Personalizes emails based on real-time company news
- References specific articles and developments to show research
- Creates empathetic, human-like tone (not robotic or spammy)
- Generates compelling subject lines and clear CTAs
- Includes spam-prevention best practices
- Professional yet warm B2B tone
=end

module Agents
  class WriterAgent
    include HTTParty
    include SettingsHelper
    base_uri "https://generativelanguage.googleapis.com/v1beta"

    def initialize(api_key:, model: "gemini-2.5-flash")
      @api_key = api_key
      @model = model
      @logger = ::Logger.new($stdout)
      raise ArgumentError, "Gemini API key is required" if @api_key.blank?
    end

    def run(search_results, recipient: nil, company: nil, product_info: nil, sender_company: nil, config: nil, shared_settings: nil, previous_critique: nil, sender_name: nil)
      # Log if this is a revision run
      if previous_critique.present?
        @logger.info("WriterAgent - REVISION MODE: Received critique feedback (#{previous_critique.length} chars)")
        @logger.info("WriterAgent - Critique preview: #{previous_critique.first(150)}...")
      else
        @logger.info("WriterAgent - INITIAL WRITE MODE: No critique feedback provided")
      end

      company_name = company || search_results[:company]
      sources = search_results[:sources]
      focus_areas = search_results[:inferred_focus_areas] || []

      # Get settings from config or use defaults
      settings = get_setting(config, :settings) || get_setting(config, "settings") || {}
      brand_voice = dig_setting(shared_settings, :brand_voice) || dig_setting(shared_settings, "brand_voice") || {}

      # Use config settings, fallback to shared_settings, then defaults
      tone = get_setting_with_default(settings, :tone) || get_setting_with_default(brand_voice, :tone, "professional")
      sender_persona = get_setting_with_default(settings, :sender_persona) || get_setting_with_default(brand_voice, :persona, "founder")
      email_length = get_setting_with_default(settings, :email_length, "short")
      personalization_level = get_setting_with_default(settings, :personalization_level, "medium")

      # Get primary_cta_type with proper fallback chain
      # Priority: agent_config settings > shared_settings > default
      primary_cta_type = get_setting(settings, :primary_cta_type) || get_setting(settings, "primary_cta_type")
      primary_cta_type ||= get_setting(shared_settings, :primary_goal) || get_setting(shared_settings, "primary_goal")
      primary_cta_type ||= "book_call"  # Default fallback

      # Validate that we got the right CTA type
      unless [ "book_call", "get_reply", "get_click" ].include?(primary_cta_type)
        @logger.warn("WriterAgent - Invalid primary_cta_type: #{primary_cta_type}, defaulting to 'book_call'")
        primary_cta_type = "book_call"
      end

      cta_softness = get_setting_with_default(settings, :cta_softness, "balanced")

      # Get num_variants_per_lead - handle both string and symbol keys, and ensure it's a number
      num_variants_raw = get_setting(settings, :num_variants_per_lead)
      num_variants = if num_variants_raw.nil?
                       2  # Default
      else
                       num_variants_raw.to_i  # Convert to integer (handles both string "1" and integer 1)
      end

      num_variants = [ 1, [ num_variants, 3 ].min ].max # Clamp between 1 and 3

      # Get product_info and sender_company from shared_settings as fallback
      product_info = product_info || get_setting(shared_settings, :product_info) || get_setting(shared_settings, "product_info") || get_setting(settings, :product_info)
      sender_company = sender_company || get_setting(shared_settings, :sender_company) || get_setting(shared_settings, "sender_company") || get_setting(settings, :sender_company)

      # Generate multiple variants if requested
      variants = []
      @logger.info("WriterAgent - Generating #{num_variants} variant(s) with primary_cta_type: #{primary_cta_type}")

      begin
        num_variants.times do |variant_index|
        prompt = build_prompt(
          company_name, sources, recipient, company_name,
          product_info, sender_company, tone, sender_persona, email_length,
          personalization_level, primary_cta_type, cta_softness, variant_index, num_variants, focus_areas,
          previous_critique: previous_critique, sender_name: sender_name
        )

        # Log a snippet of the prompt to verify CTA instruction is included
        if variant_index == 0  # Only log for first variant to avoid spam
          cta_snippet = prompt.match(/CALL-TO-ACTION.*?END CTA REQUIREMENT/m)
          @logger.info("WriterAgent - CTA instruction in prompt: #{cta_snippet ? cta_snippet[0][0..200] : 'NOT FOUND'}")
        end

        # Build full prompt with system instructions
        full_prompt = "You are an expert B2B marketing email writer who creates personalized, empathetic, and engaging outreach emails that build authentic customer relationships and drive engagement.\n\n#{prompt}"

        response = self.class.post(
          "/models/#{@model}:generateContent?key=#{@api_key}",
          headers: {
            "Content-Type" => "application/json"
          },
          body: {
            contents: [
              {
                parts: [
                  {
                    text: full_prompt
                  }
                ]
              }
            ],
            generationConfig: {
              temperature: 0.75 + (variant_index * 0.1), # Slight variation in temperature for diversity
              maxOutputTokens: 8192
            }
          }.to_json
        )

        # Check HTTP status code first
        unless response.success?
          error_body = begin
            JSON.parse(response.body)
          rescue JSON::ParserError
            response.body
          end
          error_message = error_body.is_a?(Hash) ? error_body["error"]&.dig("message") || error_body.to_s : error_body.to_s
          raise "Gemini API error (Status #{response.code}): #{error_message}"
        end

        # Check if response body is empty
        if response.body.nil? || response.body.empty?
          raise "Gemini API returned empty response"
        end

        parsed_response = begin
          JSON.parse(response.body)
        rescue JSON::ParserError => e
          raise "Failed to parse Gemini API response: #{e.message}. Response body: #{response.body[0..200]}"
        end

        # Check for API errors in response body
        if parsed_response["error"]
          error_msg = parsed_response["error"]["message"] || parsed_response["error"].to_s
          raise "Gemini API error: #{error_msg}"
        end

        # Extract email text from Gemini response
        candidate = parsed_response.dig("candidates", 0)

        if candidate && candidate["content"] && candidate["content"]["parts"]
          email = candidate["content"]["parts"][0]["text"] || "Failed to generate email"
        else
          # Log the response structure for debugging
          error_details = parsed_response.to_s[0..500] # First 500 chars
          raise "Invalid Gemini response structure. Response: #{error_details}"
        end

          variants << email
        end
      rescue => e
        # Log error details for debugging
        error_message = "WriterAgent error: #{e.class}: #{e.message}"
        @logger.error(error_message)
        @logger.error("Backtrace: #{e.backtrace.first(5).join("\n")}") if e.backtrace

        return {
          company: company || search_results[:company],
          email: "Failed to generate email",
          subject: "",
          variants: [],
          recipient: recipient,
          sources: search_results[:sources] || [],
          product_info: product_info,
          sender_company: sender_company
        }
      end

      # Return primary email (first variant) and all variants
      {
        company: company_name,
        email: variants.first || "Failed to generate email",
        variants: variants,
        recipient: recipient,
        sources: sources,
        product_info: product_info,
        sender_company: sender_company
      }
    end

    private

    def build_prompt(company_name, sources, recipient, company, product_info, sender_company, tone, sender_persona, email_length, personalization_level, primary_cta_type, cta_softness, variant_index = 0, total_variants = 1, focus_areas = [], previous_critique: nil, sender_name: nil)
      # If this is a revision based on critique feedback, adjust the prompt
      if previous_critique.present?
        prompt = "Rewrite and improve a B2B marketing outreach email based on the following critique feedback"
        prompt += " to #{recipient}" if recipient
        prompt += " at #{company}"
        prompt += ".\n\n"
        prompt += "PREVIOUS CRITIQUE FEEDBACK (address all points):\n"
        prompt += "#{previous_critique}\n\n"
        prompt += "IMPORTANT: Apply all the feedback from the critique above to create an improved version of the email.\n\n"
      else
        prompt = "Write a personalized B2B marketing outreach email"
        prompt += " to #{recipient}" if recipient
        prompt += " at #{company}"
        prompt += ".\n\n"
      end

      # Add sender company and product context if provided
      if sender_company || product_info
        prompt += "CONTEXT ABOUT YOUR COMPANY AND PRODUCT:\n"
        prompt += "#{sender_company}\n\n" if sender_company
        prompt += "#{product_info}\n\n" if product_info
      end

      if sources && !sources.empty?
        prompt += "Use the following real-time research sources to create contextually relevant content:\n\n"
        sources.each_with_index do |source, index|
          prompt += "Source #{index + 1}:\n"
          prompt += "Title: #{source['title']}\n" if source["title"]
          prompt += "URL: #{source['url']}\n" if source["url"]
          prompt += "Content: #{source['content'] || 'No content available'}\n"
          prompt += "\n"
        end
      else
        prompt += "Note: Limited sources found. Craft a compelling email that addresses key pain points.\n\n"
      end

      if focus_areas.any?
        prompt += "The recipient's technical focus areas include: #{focus_areas.join(', ')}\n\n"
      end

      prompt += "CRITICAL REQUIREMENTS:\n"
      prompt += "- Subject Line: Compelling and personalized (max 50 chars recommended)\n"

      # Personalization level guidance
      case personalization_level
      when "low"
        prompt += "- Opening: Light references to industry or company only\n"
      when "medium"
        prompt += "- Opening: Create emotional connection by referencing recent company news or industry developments. Include a clear sentence about the company or a recent event.\n"
      when "high"
        prompt += "- Opening: Heavily tailored opener that demonstrates deep research. Reference specific details, recent events, or unique company characteristics.\n"
      else
        prompt += "- Opening: Create emotional connection by referencing recent company news or industry developments\n"
      end

      prompt += "- Value Proposition: Clearly articulate how your solution addresses their specific pain points\n"
      prompt += "- Personalization Level: #{personalization_level.upcase} - #{personalization_level == 'low' ? 'Light references only' : personalization_level == 'medium' ? 'Clear sentence about company or recent event' : 'Heavily tailored opener + body'}\n"

      # Tone guidance
      tone_guidance = case tone
      when "formal"
        "Formal, respectful, and business-appropriate. Use professional language and structure."
      when "professional"
        "Professional yet warm, empathetic, and human-like (not robotic or spammy)"
      when "friendly"
        "Friendly and approachable while maintaining professionalism. Conversational but not casual."
      else
        "Professional yet warm, empathetic, and human-like"
      end
      prompt += "- Tone: #{tone_guidance}\n"
      prompt += "- Sender Persona: Write as a #{sender_persona} (#{sender_persona == 'founder' ? 'thoughtful leader' : sender_persona == 'sales' ? 'helpful sales professional' : 'supportive customer success manager'})\n"

      # Add sender name to prompt if available
      if sender_name.present?
        prompt += "- Sender Name: Your name is #{sender_name}. Use this exact name when signing the email. DO NOT use placeholders like [Your Name] or [Name].\n"
      end

      # Email length guidance
      length_guidance = case email_length
      when "very_short"
        "Very Short: 50-100 words. Extremely concise, get to the point immediately."
      when "short"
        "Short: 100-200 words. Concise and scannable, ideal for B2B outreach."
      when "standard"
        "Standard: 200-300 words. More detailed but still scannable."
      else
        "Concise and scannable (150-300 words ideal for B2B outreach)"
      end
      prompt += "- Length: #{length_guidance}\n"

      # CTA guidance - make it very explicit and prominent
      cta_guidance = case primary_cta_type
      when "book_call"
        "CRITICAL: The call-to-action MUST propose scheduling a meeting or call. Use phrases like 'schedule a call', 'book a meeting', 'set up a time', or 'let's connect'. DO NOT include links to demos or landing pages."
      when "get_reply"
        "CRITICAL: The call-to-action MUST ask for an email response. Use phrases like 'I'd love to hear your thoughts', 'What do you think?', or 'Would you be open to sharing your perspective?'. DO NOT propose meetings or include links."
      when "get_click"
        "CRITICAL: The call-to-action MUST drive the recipient to click a link, visit a demo, or go to a landing page. Use phrases like 'Check out our demo', 'See how it works', 'Explore our solution', or 'Learn more here'. Include a clear link or URL. DO NOT propose scheduling meetings or calls."
      else
        "Clear, compelling CTA that provides next steps"
      end

      cta_softness_guidance = case cta_softness
      when "soft"
        "Use gentle, non-pushy language. 'Would you be open to...' or 'I'd love to...'"
      when "balanced"
        "Use moderate assertiveness. 'I'd like to...' or 'Let's...'"
      when "direct"
        "Use clear and assertive language. 'Let's schedule...' or 'I recommend...'"
      else
        "Use balanced approach"
      end

      prompt += "\n*** CALL-TO-ACTION REQUIREMENT (MUST FOLLOW EXACTLY): ***\n"
      prompt += "#{cta_guidance}\n"
      prompt += "CTA Softness Level: #{cta_softness_guidance}\n"
      prompt += "*** END CTA REQUIREMENT ***\n\n"

      # Add variant instruction if generating multiple variants
      if total_variants > 1
        prompt += "- Variant #{variant_index + 1} of #{total_variants}: Create a unique variation while maintaining quality. Vary the opening, structure, or approach while keeping the core message consistent.\n"
      end

      prompt += "- Spam Prevention: Avoid excessive promotional language, all caps, or multiple exclamation marks\n\n"

      prompt += "Focus on:\n"
      prompt += "- Building authentic relationships, not just selling\n"
      prompt += "- Demonstrating understanding of their business context\n"
      prompt += "- Providing genuine value and insights\n"
      prompt += "- Creating an emotional connection while maintaining professionalism\n\n"

      prompt += "Format the output as:\n"
      prompt += "Subject: [email subject]\n\n"
      prompt += "[email body]"

      prompt
    end
  end
end
