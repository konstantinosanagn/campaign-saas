require 'rails_helper'

RSpec.describe SearchAgent, type: :service do
  let(:api_key) { 'test-tavily-key' }
  let(:search_agent) { described_class.new(api_key: api_key) }

  describe '#initialize' do
    context 'with valid API key' do
      it 'initializes successfully' do
        expect(search_agent).to be_a(SearchAgent)
      end
    end

    context 'with blank API key' do
      it 'raises ArgumentError' do
        expect {
          described_class.new(api_key: '')
        }.to raise_error(ArgumentError, 'Tavily API key is required')
      end
    end

    context 'with nil API key' do
      it 'raises ArgumentError' do
        expect {
          described_class.new(api_key: nil)
        }.to raise_error(ArgumentError, 'Tavily API key is required')
      end
    end
  end

  describe '#run' do
    let(:domain) { 'example.com' }
    let(:mock_response) do
      {
        'results' => [
          {
            'title' => 'Example News Article',
            'url' => 'https://example.com/news',
            'content' => 'This is example content'
          },
          {
            'title' => 'Another Article',
            'url' => 'https://example.com/article',
            'content' => 'More example content'
          }
        ]
      }
    end

    before do
      allow(search_agent).to receive(:tavily_search).and_return(mock_response)
    end

    it 'returns domain and sources' do
      result = search_agent.run(domain)

      expect(result).to include(
        domain: domain,
        sources: mock_response['results']
      )
    end

    it 'calls search with correct parameters' do
      expect(search_agent).to receive(:tavily_search).with(
        "latest news about #{domain}",
        topic: 'news'
      )

      search_agent.run(domain)
    end

    context 'when API returns empty results' do
      let(:empty_response) { {} }

      before do
        allow(search_agent).to receive(:tavily_search).and_return(empty_response)
      end

      it 'returns empty sources array' do
        result = search_agent.run(domain)

        expect(result[:sources]).to eq([])
      end
    end

    context 'when API returns nil results' do
      let(:nil_response) { { 'results' => nil } }

      before do
        allow(search_agent).to receive(:tavily_search).and_return(nil_response)
      end

      it 'returns empty sources array' do
        result = search_agent.run(domain)

        expect(result[:sources]).to eq([])
      end
    end
  end

  describe '#tavily_search' do
    let(:query) { 'test query' }
    let(:topic) { 'news' }
    let(:mock_response) { double('response', body: '{"results": []}') }

    before do
      allow(described_class).to receive(:post).and_return(mock_response)
      allow(JSON).to receive(:parse).and_return({ 'results' => [] })
    end

    it 'makes POST request to correct endpoint' do
      expect(described_class).to receive(:post).with(
        '/search',
        headers: {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{api_key}"
        },
        body: {
          query: query,
          topic: topic,
          max_results: 5,
          include_images: false
        }.to_json
      )

      search_agent.send(:tavily_search, query, topic: topic)
    end

    it 'parses JSON response' do
      expect(JSON).to receive(:parse).with('{"results": []}')

      search_agent.send(:tavily_search, query, topic: topic)
    end

    it 'returns parsed response' do
      result = search_agent.send(:tavily_search, query, topic: topic)

      expect(result).to eq({ 'results' => [] })
    end

    context 'when API call raises an error' do
      before do
        allow(described_class).to receive(:post).and_raise(StandardError, 'Network error')
        allow(JSON).to receive(:parse).and_raise(StandardError, 'JSON parse error')
      end

      it 'handles error gracefully and returns empty hash' do
        expect {
          result = search_agent.send(:tavily_search, query, topic: topic)
          expect(result).to eq({})
        }.not_to raise_error
      end

      it 'logs error message' do
        expect {
          search_agent.send(:tavily_search, query, topic: topic)
        }.to output(/Tavily error: Network error/).to_stdout
      end
    end
  end

  describe 'HTTParty configuration' do
    it 'includes HTTParty module' do
      expect(SearchAgent.included_modules).to include(HTTParty)
    end

    it 'sets correct base_uri' do
      expect(SearchAgent.base_uri).to eq('https://api.tavily.com')
    end
  end
end
