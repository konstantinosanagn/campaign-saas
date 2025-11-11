require "httparty"
require "json"

=begin
WRITER AGENT

OVERVIEW:
The WriterAgent uses Google's Gemini AI to generate personalized, contextually-aware B2B marketing emails
for target companies. It transforms research data from SearchAgent into compelling, human-like outreach emails.

HOW IT WORKS:
1. Receives search results from SearchAgent containing company news, articles, and images
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
    base_uri "https://generativelanguage.googleapis.com/v1beta"

    def initialize(api_key:, model: "gemini-2.5-flash")
      @api_key = api_key
      @model = model
      raise ArgumentError, "Gemini API key is required" if @api_key.blank?
    end

    def run(search_results, recipient: nil, company: nil, product_info: nil, sender_company: nil, config: nil, shared_settings: nil)
      company_name = company || search_results[:company]
      sources = search_results[:sources]
      image = search_results[:image]

      # Get settings from config or use defaults
      settings = config&.dig("settings") || config&.dig(:settings) || {}
      brand_voice = shared_settings&.dig("brand_voice") || shared_settings&.dig(:brand_voice) || {}

      # Use config settings, fallback to shared_settings, then defaults
      tone = settings["tone"] || settings[:tone] || brand_voice["tone"] || brand_voice[:tone] || "professional"
      sender_persona = settings["sender_persona"] || settings[:sender_persona] || brand_voice["persona"] || brand_voice[:persona] || "founder"
      email_length = settings["email_length"] || settings[:email_length] || "short"
      personalization_level = settings["personalization_level"] || settings[:personalization_level] || "medium"
      primary_cta_type = settings["primary_cta_type"] || settings[:primary_cta_type] || shared_settings&.dig("primary_goal") || shared_settings&.dig(:primary_goal) || "book_call"
      cta_softness = settings["cta_softness"] || settings[:cta_softness] || "balanced"
      num_variants = (settings["num_variants_per_lead"] || settings[:num_variants_per_lead] || 2).to_i
      num_variants = [ 1, [ num_variants, 3 ].min ].max # Clamp between 1 and 3

      # Get product_info and sender_company from shared_settings as fallback
      product_info = product_info || shared_settings&.dig("product_info") || shared_settings&.dig(:product_info) || settings["product_info"] || settings[:product_info]
      sender_company = sender_company || shared_settings&.dig("sender_company") || shared_settings&.dig(:sender_company) || settings["sender_company"] || settings[:sender_company]

      # Generate multiple variants if requested
      variants = []
      num_variants.times do |variant_index|
        prompt = build_prompt(
          company_name, sources, image, recipient, company_name,
          product_info, sender_company, tone, sender_persona, email_length,
          personalization_level, primary_cta_type, cta_softness, variant_index, num_variants
        )

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

        parsed_response = JSON.parse(response.body)

        # Extract email text from Gemini response
        candidate = parsed_response.dig("candidates", 0)

        if candidate && candidate["content"] && candidate["content"]["parts"]
          email = candidate["content"]["parts"][0]["text"] || "Failed to generate email"
        else
          email = "Failed to generate email"
        end

        variants << email
      end

      # Return primary email (first variant) and all variants
      {
        company: company_name,
        email: variants.first || "Failed to generate email",
        variants: variants,
        recipient: recipient,
        sources: sources,
        image: image,
        product_info: product_info,
        sender_company: sender_company
      }
    rescue => e
      {
        company: company || search_results[:company],
        email: "Error generating email: #{e.message}",
        recipient: recipient,
        sources: search_results[:sources] || [],
        image: search_results[:image],
        product_info: product_info,
        sender_company: sender_company,
        error: "WriterAgent LLM error: #{e.class}: #{e.message}"
      }
    end

    private

    def build_prompt(company_name, sources, image, recipient, company, product_info, sender_company, tone, sender_persona, email_length, personalization_level, primary_cta_type, cta_softness, variant_index = 0, total_variants = 1)
      prompt = "Write a personalized B2B marketing outreach email"
      prompt += " to #{recipient}" if recipient
      prompt += " at #{company}"
      prompt += ".\n\n"

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

      if image
        prompt += "Consider incorporating visual elements. Image URL: #{image}\n\n"
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

      # CTA guidance
      cta_guidance = case primary_cta_type
      when "book_call"
        "Propose a short intro meeting (15-30 minutes). Make it easy to schedule."
      when "get_reply"
        "Ask for a quick email response. Pose a thoughtful question or request feedback."
      when "get_click"
        "Drive to a link/demo/landing page. Provide clear value proposition for clicking."
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

      prompt += "- Call-to-Action: #{cta_guidance}. CTA Softness: #{cta_softness_guidance}\n"

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
