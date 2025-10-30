require 'httparty'
require 'json'

##
# SearchAgent integrates with the Tavily API to fetch recent news
# a given domain (target company).
# @return Top 5 news sources (based on google search results rankings)
# as json as output

class SearchAgent
  include HTTParty
  base_uri 'https://api.tavily.com'

  def initialize(api_key:)
    @api_key = api_key
    raise ArgumentError, "Tavily API key is required" if @api_key.blank?
  end

  # Get recent news sources for a domain (target company)
  def run(domain)
    {
      domain: domain,
      sources: search(domain)
    }
  end

  private

  # Private helper method to launch the Tavily search query
  # @param domain [String]
  # @return [Array<Hash>] list of news sources
  def search(domain)
    query = "latest news about #{domain}"
    results = tavily_search(query, topic: 'news')
    results['results'] || []
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
        include_images: false
      }.to_json
    )
    JSON.parse(response.body)
  rescue => e
    {}
  end
end
