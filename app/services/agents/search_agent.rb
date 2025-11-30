# app/services/agents/search_agent.rb

require "httparty"
require "json"
require "logger"

module Agents
  class SearchAgent
    include HTTParty
    base_uri "https://api.tavily.com"  # For Tavily

    GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta"

    def initialize(tavily_key:, gemini_key:, model: "gemini-2.5-flash")
      raise ArgumentError, "Tavily API key is required" if tavily_key.nil? || tavily_key.empty?
      raise ArgumentError, "Gemini API key is required" if gemini_key.nil? || gemini_key.empty?

      @tavily_key = tavily_key
      @gemini_key = gemini_key
      @model = model
      @logger = ::Logger.new($stdout)
    end

    def run(company:, recipient_name:, job_title:, email:, tone: nil, persona: nil, goal: nil)
      identity = {
        name: recipient_name,
        company: company,
        job_title: job_title,
        email: email
      }

      @logger.info("SearchAgent: Personalization lookup for #{recipient_name} @ #{company}")

      inferred_focus_areas = infer_focus_areas(identity, tone: tone, persona: persona, goal: goal)

      recipient_query = "#{recipient_name} #{company} #{job_title}"
      company_query = "#{company} #{inferred_focus_areas.join(', ')}"

      recipient_signals = run_tavily_search(recipient_query)
      company_signals = run_tavily_search(company_query)

      {
        target_identity: identity,
        inferred_focus_areas: inferred_focus_areas,
        personalization_signals: {
          recipient: recipient_signals,
          company: company_signals
        }
      }
    end

    private

    def infer_focus_areas(identity, tone:, persona:, goal:)
      tone ||= ""
      persona ||= ""
      goal ||= ""

      prompt = <<~PROMPT
        Given the recipient below, infer 3–5 technical focus areas or themes likely relevant to them in their work. Output only a JSON array of short phrases.
        Recipient:
        - Name: #{identity[:name]}
        - Job Title: #{identity[:job_title]}
        - Company: #{identity[:company]}
        - Email: #{identity[:email]}
        - Sender Persona: #{persona}
        - Email Tone: #{tone}
        - Goal: #{goal}
      PROMPT

      response = HTTParty.post(
        "https://generativelanguage.googleapis.com/v1beta/models/#{@model}:generateContent?key=#{@gemini_key}",
        headers: { "Content-Type" => "application/json" },
        body: {
          contents: [ { parts: [ { text: prompt } ] } ]
        }.to_json
      )

      raw = response.parsed_response.dig("candidates", 0, "content", "parts", 0, "text") || ""

      # @logger.debug("Gemini raw response: #{raw}")

      # Remove markdown and surrounding quotes
      cleaned = raw
        .gsub(/```json/i, "")
        .gsub(/```/, "")
        .gsub(/\A\s+|\s+\z/, "")  # trim leading/trailing whitespace
        .gsub("\n", "")           # remove line breaks

      JSON.parse(cleaned)
    rescue => e
      @logger.error("Gemini inference failed: #{e.message}")
      []
    end



    def run_tavily_search(query)
      # Tavily API requires the key in Authorization header, not body
      # Format: "Bearer tvly-{key}" 
      # The key stored may already include "tvly-" prefix (e.g., "tvly-dev-xxx")
      # or may be just the key part (e.g., "dev-xxx")
      auth_key = @tavily_key.start_with?("tvly-") ? @tavily_key : "tvly-#{@tavily_key}"
      
      response = self.class.post(
        "/search",
        headers: {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{auth_key}"
        },
        body: {
          query: query,
          search_depth: "advanced",
          include_answer: false,
          include_raw_content: false,
          max_results: 5
        }.to_json
      )

      # Check HTTP status code first
      unless response.success?
        error_body = response.parsed_response rescue response.body
        @logger.error("Tavily API request failed - Status: #{response.code}, Response: #{error_body.inspect}")
        return []
      end

      begin
        parsed = response.parsed_response
        sources = parsed["results"]
        
        if sources.nil?
          @logger.warn("Tavily API returned no 'results' field. Full response: #{parsed.inspect}")
          return []
        end

        sources.map do |result|
          {
            title: result["title"],
            url: result["url"],
            content: result["content"]
          }
        end
      rescue => e
        @logger.error("Tavily batch search failed: #{e.message}")
        @logger.error("Response body: #{response.body.inspect}") if response.respond_to?(:body)
        @logger.error("Backtrace: #{e.backtrace.first(5).join("\n")}")
        []
      end
    end
  end
end
