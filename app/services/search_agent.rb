require "httparty"
require "dotenv/load"
require "json"
require "logger"

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
  def run(domain, recipient: nil)
    @logger.info("Running search for domain=#{domain.inspect}, recipient=#{recipient.inspect}")

    domain_sources = domain.present? ? domain_search(domain) : []
    recipient_sources = recipient.present? ? recipient_search(recipient) : []

    {
      domain: {
        domain: domain,
        sources: domain_sources
      },
      recipient: {
        name: recipient,
        sources: recipient_sources
      },
      sources: domain_sources + recipient_sources
    }
  end

  private

  # Private helper method to launch the Tavily search query
  # @param entity [String]
  # @return [Array<Hash>] list of news sources
  def domain_search(entity)
    query = "latest news about #{entity}"
    results = tavily_search(query, topic: "news")
    (results["results"] || []).first(5)
  end

  def recipient_search(name)
    return [] if name.blank?

    queries = [
      "#{name} LinkedIn",
      "#{name} profile",
      "#{name} professional background"
    ]

    queries.flat_map do |query|
      res = tavily_search(query, topic: "general")
      res["results"] || []
    end.uniq { |result| result["url"] }.first(5)
  end

  # Method to perform a Tavily API request
  # @return [Hash] parsed response
  def tavily_search(query, topic:, include_images: false)
    response = self.class.post(
      "/search",
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{@api_key}"
      },
      body: {
        query: query,
        topic: topic,
        max_results: 5,
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
