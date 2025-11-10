require "httparty"
begin
  require "dotenv/load"
rescue LoadError
  # Dotenv is optional in production environments (e.g. Heroku)
end
require "json"
require "logger"

module Agents
  ##
  # SearchAgent integrates with the Tavily API to fetch recent news and background
  # information about a target company (domain) and optional recipient.
  # @return Top 5 news sources for both company and recipient.
  class SearchAgent
    include HTTParty
    base_uri "https://api.tavily.com"

    def initialize(api_key: ENV["TAVILY_API_KEY"], logger: ::Logger.new($stdout))
      @api_key = api_key
      @logger = logger || ::Logger.new($stdout)
      raise ArgumentError, "Tavily API key is required" if @api_key.blank?
    end

    # Get recent news sources for a domain (target company) and optional recipient
    # @param domain [String] Company domain or name
    # @param recipient [String, nil] Optional recipient name
    # @param config [Hash, nil] Agent configuration with settings
    #   - search_depth: 'basic' | 'advanced'
    #   - max_queries_per_lead: Integer (default: 2)
    #   - extracted_fields: Array of field names
    #   - on_low_info_behavior: 'generic_industry' | 'light_personalization' | 'skip'
    def run(domain, recipient: nil, config: nil)
      @logger.info("Running search for domain=#{domain.inspect}, recipient=#{recipient.inspect}, config=#{config.inspect}")

      settings = config&.dig("settings") || config&.dig(:settings) || {}
      search_depth = settings["search_depth"] || settings[:search_depth] || "basic"
      max_queries = (settings["max_queries_per_lead"] || settings[:max_queries_per_lead] || 2).to_i
      extracted_fields = settings["extracted_fields"] || settings[:extracted_fields] || []
      on_low_info = settings["on_low_info_behavior"] || settings[:on_low_info_behavior] || "generic_industry"

      # Determine max_results based on search_depth
      max_results = search_depth == "advanced" ? 10 : 5

      domain_sources = domain.present? ? domain_search(domain, max_results: max_results, max_queries: max_queries) : []
      recipient_sources = recipient.present? ? recipient_search(recipient, max_results: max_results, max_queries: max_queries) : []

      # Check if we have low information
      total_sources = domain_sources.length + recipient_sources.length
      has_low_info = total_sources < 3

      # Handle low info behavior
      if has_low_info && on_low_info == "skip"
        @logger.info("Low information detected (#{total_sources} sources), skipping per config")
        return {
          domain: { domain: domain, sources: [] },
          recipient: { name: recipient, sources: [] },
          sources: [],
          low_info_flag: true,
          on_low_info_behavior: on_low_info
        }
      end

      # Combine and cap total sources at 10
      combined_sources = domain_sources + recipient_sources
      capped_sources = combined_sources.first(10)

      # Extract specified fields if any
      enriched_sources = if extracted_fields.any?
        capped_sources.map do |source|
          enriched = source.dup
          # Note: Tavily API already provides title, url, content
          # Additional field extraction would require additional processing
          enriched
        end
      else
        capped_sources
      end

      {
        domain: {
          domain: domain,
          sources: domain_sources.first(10) # Cap domain sources at 10
        },
        recipient: {
          name: recipient,
          sources: recipient_sources.first(10) # Cap recipient sources at 10
        },
        sources: enriched_sources,
        extracted_fields: extracted_fields,
        search_depth: search_depth,
        on_low_info_behavior: on_low_info
      }
    end

    private

    # Private helper method to launch the Tavily search query
    # @param entity [String]
    # @param max_results [Integer] Maximum number of results to return
    # @param max_queries [Integer] Maximum number of queries to execute
    # @return [Array<Hash>] list of news sources
    def domain_search(entity, max_results: 5, max_queries: 2)
      queries = if max_queries > 1
        [
          "latest news about #{entity}",
          "#{entity} company updates",
          "#{entity} business news"
        ].first(max_queries)
      else
        [ "latest news about #{entity}" ]
      end

      all_results = queries.flat_map do |query|
        results = tavily_search(query, topic: "news", max_results: max_results)
        results["results"] || []
      end

      # Remove duplicates by URL and limit results
      all_results.uniq { |result| result["url"] }.first(max_results)
    end

    def recipient_search(name, max_results: 5, max_queries: 2)
      return [] if name.blank?

      queries = [
        "#{name} LinkedIn",
        "#{name} profile",
        "#{name} professional background",
        "#{name} executive",
        "#{name} career"
      ].first(max_queries)

      all_results = queries.flat_map do |query|
        res = tavily_search(query, topic: "general", max_results: max_results)
        res["results"] || []
      end

      # Remove duplicates by URL and limit results
      all_results.uniq { |result| result["url"] }.first(max_results)
    end

    # Method to perform a Tavily API request
    # @param query [String] Search query
    # @param topic [String] Search topic (news, general, etc.)
    # @param max_results [Integer] Maximum number of results
    # @param include_images [Boolean] Whether to include images
    # @return [Hash] parsed response
    def tavily_search(query, topic:, max_results: 5, include_images: false)
      response = self.class.post(
        "/search",
        headers: {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{@api_key}"
        },
        body: {
          query: query,
          topic: topic,
          max_results: max_results,
          include_images: include_images
        }.to_json
      )
      JSON.parse(response.body)
    rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout => e
      @logger.error("Tavily error: #{e.message}")
      {}
    rescue StandardError => e
      @logger.error("Tavily error: #{e.message}")
      {}
    end
  end
end
