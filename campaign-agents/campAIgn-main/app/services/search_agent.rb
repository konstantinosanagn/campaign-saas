require 'httparty'
require 'dotenv/load'
require 'json'
require 'logger'

##
# SearchAgent integrates with the Tavily API to fetch recent news
# a given domain (target company).
# @return Top 5 news sources (based on google search results rankings)
# as json as output

class SearchAgent
  include HTTParty
  base_uri 'https://api.tavily.com'

  def initialize(api_key: ENV['TAVILY_API_KEY'])
    @api_key = api_key
    @logger = ::Logger.new($stdout)

  end

  # Get recent news sources for a domain (target company)
  def run(domain, recipient)
    @logger.info("Running search for domain=#{domain.inspect}, recipient=#{recipient.inspect}")

    domain_sources = domain.nil? || domain.strip.empty? ? [] : domain_search(domain)
    recipient_sources = recipient.nil? || recipient.strip.empty? ? [] : recipient_search(recipient)


    {
      domain:{
        domain: domain,
        sources: domain_sources
      },
      recipient:{
        name: recipient,
        sources: recipient_sources
      }
    }
  end

  private

  # Private helper method to launch the Tavily search query
  # @param domain [String]
  # @return [Array<Hash>] list of news sources

  def domain_search(entity) # For Target Company
    query = "latest news about #{entity}"
    results = tavily_search(query, topic: 'news')
    (results['results'] || []).first(5)
  end

  def recipient_search(name) # For recipient
    return [] if name.nil? || name.strip.empty?

    queries = [
      "#{name} LinkedIn",
      "#{name} profile",
      "#{name} professional background"
    ]

    all_results = queries.flat_map do |q|
      res = tavily_search(q, topic: 'general')
      res['results'] || []
    end

    all_results.uniq { |r| r["url"] }.first(5)
    end

  # Method to perform a Tavily API request
  # @return [Hash] parsed response
  def tavily_search(query, topic:, include_images:false)
    response = self.class.post(
      '/search',
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{@api_key}"
      },
      body: {
        query: query,
        topic: topic,
        max_results: 5,
        include_images: include_images
      }.to_json
    )
    JSON.parse(response.body)
  rescue JSON::ParserError => e
    @logger.error("Tavily error: #{e.message}")
    {}
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    @logger.error("Tavily error: #{e.message}")
    {}
  rescue StandardError => e
    @logger.error("Tavily error: #{e.message}")
    {}
  end
end
