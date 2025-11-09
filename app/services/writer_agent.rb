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

class WriterAgent
  include HTTParty
  base_uri "https://generativelanguage.googleapis.com/v1beta"

  def initialize(api_key:, model: "gemini-2.5-flash")
    @api_key = api_key
    @model = model
    raise ArgumentError, "Gemini API key is required" if @api_key.blank?
  end

  def run(search_results, recipient: nil, company: nil, product_info: nil, sender_company: nil)
    company_name = company || search_results[:company]
    sources = search_results[:sources]
    image = search_results[:image]

    prompt = build_prompt(company_name, sources, image, recipient, company_name, product_info, sender_company)

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
          temperature: 0.75,
          maxOutputTokens: 8192
        }
      }.to_json
    )

    parsed_response = JSON.parse(response.body)

    # Extract email text from Gemini response
    candidate = parsed_response.dig("candidates", 0)

    # Extract email text from Gemini response
    if candidate && candidate["content"] && candidate["content"]["parts"]
      email = candidate["content"]["parts"][0]["text"] || "Failed to generate email"
    else
      email = "Failed to generate email"
    end

    {
      company: company_name,
      email: email,
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
      sources: search_results[:sources],
      image: search_results[:image],
      product_info: product_info,
      sender_company: sender_company
    }
  end

  private

  def build_prompt(company_name, sources, image, recipient, company, product_info, sender_company)
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
    prompt += "- Opening: Create emotional connection by referencing recent company news or industry developments\n"
    prompt += "- Value Proposition: Clearly articulate how your solution addresses their specific pain points\n"
    prompt += "- Personalization: Reference specific details from the research sources to show you've done your homework\n"
    prompt += "- Tone: Professional yet warm, empathetic, and human-like (not robotic or spammy)\n"
    prompt += "- Call-to-Action: Clear, compelling CTA that provides next steps\n"
    prompt += "- Length: Concise and scannable (150-300 words ideal for B2B outreach)\n"
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
