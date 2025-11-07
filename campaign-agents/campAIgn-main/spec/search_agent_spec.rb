require_relative 'spec_helper'

RSpec.describe SearchAgent do
  let(:api_key) { 'test_tavily_key' }
  let(:agent) { described_class.new(api_key: api_key) }
  let(:domain) { 'Columbia' }
  let(:recipient) { 'Aarushi Sharma' }

  describe 'initialization' do
    it 'accepts custom API key' do
      custom_agent = described_class.new(api_key: 'custom_key')
      expect(custom_agent.instance_variable_get(:@api_key)).to eq('custom_key')
    end
  end

  # Real API Tests
  context 'with real API requests', real: true do
    before do
      WebMock.allow_net_connect!
    end

    it 'fetches real data from the Tavily API' do
      result = agent.run(domain, recipient)

      expect(result).to be_a(Hash)
      expect(result[:domain][:sources]).to be_an(Array)
      expect(result[:recipient][:sources]).to be_an(Array)
    end
  end

  # Mocked API Tests
  context 'with mocked API requests' do
    before do
      WebMock.disable_net_connect!
    end
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
        result = agent.run(domain,recipient)

        # Check domain results
        expect(result[:domain]).to have_key(:domain)
        expect(result[:domain][:domain]).to eq(domain)
        expect(result[:domain][:sources]).to be_an(Array)
        expect(result[:domain][:sources].first['title']).to eq('OpenAI launches GPT-5')

        # Check recipient results
        expect(result[:recipient]).to have_key(:name)
        expect(result[:recipient][:name]).to eq(recipient)
        expect(result[:recipient][:sources]).to be_an(Array)
        expect(result[:recipient][:sources].first['title']).to eq('OpenAI launches GPT-5')
      end
    end

    context 'with missing or empty parameters' do
      before do
        stub_request(:post, 'https://api.tavily.com/search')
          .with(
            body: hash_including(query: 'latest news about '),
            headers: {
              'Authorization' => "Bearer #{api_key}",
              'Content-Type' => 'application/json'
            }
          )
          .to_return(status: 200, body: { results: [] }.to_json, headers: { 'Content-Type' => 'application/json' })
      end

            it 'handles nil or empty domain and recipient gracefully' do
        [ [nil, nil], ['', ''] ].each do |domain, recipient|
          result = agent.run(domain, recipient)
          expect(result[:domain][:sources]).to eq([])
          expect(result[:recipient][:sources]).to eq([])
        end
      end
    end
  
    context 'with an invalid API key' do
      let(:agent) { described_class.new(api_key: 'invalid_key') }
      before do
        stub_request(:post, 'https://api.tavily.com/search')
          .to_return(status: 401, body: 'Unauthorized')
      end
    
      it 'handles authentication errors gracefully' do
        result = agent.run(domain, recipient)
        expect(result[:domain][:sources]).to eq([])
        expect(result[:recipient][:sources]).to eq([])
      end
    end  

    context 'with API error' do
      before do
        stub_request(:post, 'https://api.tavily.com/search')
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'handles errors gracefully' do
        result = agent.run(domain,recipient)
        expect(result).to be_a(Hash)
        expect(result[:domain][:sources]).to eq([])
        expect(result[:recipient][:sources]).to eq([])
      end
    end

    context 'with timeout' do
      before do
        stub_request(:post, 'https://api.tavily.com/search').to_timeout
      end

      it 'handles network timeouts gracefully' do
        result = agent.run(domain, recipient)
        expect(result[:domain][:sources]).to eq([])
        expect(result[:recipient][:sources]).to eq([])
      end
    end

    context 'with malformed JSON response' do
      before do
        stub_request(:post, 'https://api.tavily.com/search')
          .to_return(status: 200, body: 'not-json')
      end

      it 'handles JSON parse errors gracefully' do
        result = agent.run(domain,recipient)
        expect(result).to be_a(Hash)
        expect(result[:domain][:sources]).to eq([])
        expect(result[:recipient][:sources]).to eq([])
      end
    end

    context 'with a large API response' do
      let(:large_response) do
        {
          'results' => Array.new(10) { |i| { 'title' => "News #{i + 1}", 'url' => "https://example.com/news#{i + 1}" } }
        }
      end

      before do
        stub_request(:post, 'https://api.tavily.com/search')
          .to_return(status: 200, body: large_response.to_json)
      end

      it 'handles large responses and limits to 5 results' do
        result = agent.run(domain, recipient)
        expect(result[:domain][:sources].size).to eq(5) 
        expect(result[:recipient][:sources].size).to eq(5)
      end
    end
  
  end
end

