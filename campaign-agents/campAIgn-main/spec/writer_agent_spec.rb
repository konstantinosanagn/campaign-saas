require 'spec_helper'

RSpec.describe WriterAgent do
  let(:api_key) { 'test_gemini_key' }
  let(:agent) { described_class.new(api_key: api_key) }
  
  let(:search_results) do
    {
      company: 'Microsoft',
      sources: [
        {
          'title' => 'Microsoft partners with OpenAI',
          'url' => 'https://example.com/microsoft-openai',
          'content' => 'Microsoft announced new AI initiatives...'
        },
        {
          'title' => 'Microsoft Cloud revenue grows',
          'url' => 'https://example.com/microsoft-cloud',
          'content' => 'Azure services see 20% growth...'
        }
      ],
      image: 'https://example.com/microsoft-logo.jpg'
    }
  end

  describe 'initialization' do
    it 'accepts custom API key' do
      custom_agent = described_class.new(api_key: 'custom_key')
      expect(custom_agent.instance_variable_get(:@api_key)).to eq('custom_key')
    end

    it 'accepts custom model' do
      custom_agent = described_class.new(api_key: api_key, model: 'gemini-2.5-pro')
      expect(custom_agent.instance_variable_get(:@model)).to eq('gemini-2.5-pro')
    end

    it 'defaults to gemini-2.5-flash model' do
      expect(agent.instance_variable_get(:@model)).to eq('gemini-2.5-flash')
    end
  end

  describe '#run' do
    context 'with successful API response' do
      let(:mock_response) do
        {
          'candidates' => [
            {
              'content' => {
                'parts' => [
                  {
                    'text' => 'Subject: Partnering with Microsoft\n\nHi John,\n\nI saw Microsoft\'s recent partnership...'
                  }
                ]
              },
              'finishReason' => 'STOP'
            }
          ]
        }
      end

      before do
        stub_request(:post, /generativelanguage.googleapis.com\/v1beta\/models\/gemini-2.5-flash:generateContent/)
          .with(
            query: { key: api_key }
          )
          .to_return(
            status: 200,
            body: mock_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'generates a personalized email' do
        result = agent.run(search_results, recipient: 'John Doe', company: 'Microsoft')

        expect(result).to have_key(:company)
        expect(result).to have_key(:email)
        expect(result).to have_key(:recipient)
        expect(result[:email]).to be_a(String)
        expect(result[:email].length).to be > 0
      end

      it 'includes recipient and company in output' do
        result = agent.run(search_results, recipient: 'Sarah Chen', company: 'Microsoft')

        expect(result[:company]).to eq('Microsoft')
        expect(result[:recipient]).to eq('Sarah Chen')
        expect(result[:sources]).to eq(search_results[:sources])
        expect(result[:image]).to eq(search_results[:image])
      end

      it 'handles optional recipient parameter' do
        result = agent.run(search_results, company: 'Microsoft')

        expect(result[:recipient]).to be_nil
        expect(result[:email]).to be_a(String)
      end

      it 'includes product_info and sender_company in output when provided' do
        result = agent.run(
          search_results, 
          recipient: 'John Doe', 
          company: 'Microsoft',
          product_info: 'AI automation platform',
          sender_company: 'Acme Corp'
        )

        expect(result[:product_info]).to eq('AI automation platform')
        expect(result[:sender_company]).to eq('Acme Corp')
      end

      it 'includes sources in the API request' do
        agent.run(search_results, recipient: 'John Doe', company: 'Microsoft')

        expect(a_request(:post, 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent')
          .with(query: { key: api_key })).to have_been_made
      end
    end

    context 'with API error' do
      before do
        stub_request(:post, /generativelanguage.googleapis.com\/v1beta\/models\/gemini-2.5-flash:generateContent/)
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'handles errors gracefully' do
        result = agent.run(search_results)

        expect(result).to have_key(:company)
        expect(result[:email]).to include('Error generating email')
      end
    end

    context 'with empty sources' do
      let(:empty_search_results) do
        {
          company: 'Startup Corp',
          sources: [],
          image: nil
        }
      end

      before do
        stub_request(:post, /generativelanguage.googleapis.com\/v1beta\/models\/gemini-2.5-flash:generateContent/)
          .to_return(
            status: 200,
            body: { 'candidates' => [{ 'content' => { 'parts' => [{ 'text' => 'Email content' }] } }] }.to_json
          )
      end

      it 'still generates an email without sources' do
        result = agent.run(empty_search_results)

        expect(result[:email]).to be_a(String)
        expect(result[:company]).to eq('Startup Corp')
      end
    end

    context 'with timeout' do
      before do
        stub_request(:post, /generativelanguage.googleapis.com\/v1beta\/models\/gemini-2.5-flash:generateContent/)
          .to_timeout
      end

      it 'handles network timeouts' do
        result = agent.run(search_results)

        expect(result).to have_key(:company)
        expect(result[:email]).to include('Error generating email')
      end
    end

    context 'with malformed API response' do
      before do
        stub_request(:post, /generativelanguage.googleapis.com\/v1beta\/models\/gemini-2.5-flash:generateContent/)
          .to_return(
            status: 200,
            body: 'not json',
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'handles JSON parsing errors' do
        result = agent.run(search_results)

        expect(result).to have_key(:company)
        expect(result[:email]).to include('Error generating email')
      end
    end
  end
end
