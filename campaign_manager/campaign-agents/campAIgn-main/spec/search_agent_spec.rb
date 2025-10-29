require 'spec_helper'

RSpec.describe SearchAgent do
  let(:api_key) { 'test_tavily_key' }
  let(:agent) { described_class.new(api_key: api_key) }
  let(:domain) { 'OpenAI' }

  describe 'initialization' do
    it 'accepts custom API key' do
      custom_agent = described_class.new(api_key: 'custom_key')
      expect(custom_agent.instance_variable_get(:@api_key)).to eq('custom_key')
    end
  end

  describe '#run' do
    context 'with successful API response' do
      let(:mock_search_response) do
        {
          'results' => [
            { 'title' => 'OpenAI launches GPT-5', 'url' => 'https://example.com/openai-gpt5' },
            { 'title' => 'OpenAI partners with Microsoft', 'url' => 'https://example.com/openai-msft' }
          ],
          'images' => ['https://example.com/openai-logo.png']
        }
      end

      before do
        stub_request(:post, 'https://api.tavily.com/search')
          .with(
            headers: {
              'Content-Type' => 'application/json',
              'Authorization' => "Bearer #{api_key}"
            }
          )
          .to_return(status: 200, body: mock_search_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns a hash with domain and sources' do
        result = agent.run(domain)

        expect(result).to be_a(Hash)
        expect(result[:domain]).to eq('OpenAI')
        expect(result[:sources]).to be_an(Array)
        expect(result[:sources].first['title']).to eq('OpenAI launches GPT-5')
      end
    end

    context 'with API error' do
      before do
        stub_request(:post, 'https://api.tavily.com/search')
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'handles errors gracefully' do
        result = agent.run(domain)
        expect(result).to be_a(Hash)
        expect(result[:sources]).to eq([])
      end
    end

    context 'with timeout' do
      before do
        stub_request(:post, 'https://api.tavily.com/search').to_timeout
      end

      it 'handles network timeouts gracefully' do
        result = agent.run(domain)
        expect(result[:sources]).to eq([])
      end
    end

    context 'with malformed JSON response' do
      before do
        stub_request(:post, 'https://api.tavily.com/search')
          .to_return(status: 200, body: 'not-json')
      end

      it 'handles JSON parse errors gracefully' do
        result = agent.run(domain)
        expect(result).to be_a(Hash)
        expect(result[:sources]).to eq([])
      end
    end
  end
end
