require 'rails_helper'

RSpec.describe Agents::WriterAgent, type: :service do
  let(:api_key) { 'test-gemini-key' }
  let(:writer_agent) { described_class.new(api_key: api_key) }

  describe '#initialize' do
    context 'with valid API key' do
      it 'initializes successfully' do
        expect(writer_agent).to be_a(described_class)
      end

      it 'sets default model' do
        expect(writer_agent.instance_variable_get(:@model)).to eq('gemini-2.5-flash')
      end
    end

    context 'with custom model' do
      let(:custom_model) { 'gemini-pro' }
      let(:agent) { described_class.new(api_key: api_key, model: custom_model) }

      it 'sets custom model' do
        expect(agent.instance_variable_get(:@model)).to eq(custom_model)
      end
    end

    context 'with blank API key' do
      it 'raises ArgumentError' do
        expect {
          described_class.new(api_key: '')
        }.to raise_error(ArgumentError, 'Gemini API key is required')
      end
    end

    context 'with nil API key' do
      it 'raises ArgumentError' do
        expect {
          described_class.new(api_key: nil)
        }.to raise_error(ArgumentError, 'Gemini API key is required')
      end
    end
  end

  describe '#run' do
    let(:search_results) do
      {
        company: 'Test Corp',
        sources: [
          {
            "title" => "Test Article",
            "url" => "https://test.com/article",
            "content" => "Test content"
          }
        ],
        inferred_focus_areas: []
      }
    end
    let(:recipient) { 'John Doe' }
    let(:company) { 'Test Corp' }
    let(:product_info) { 'Our amazing product' }
    let(:sender_company) { 'My Company' }
    let(:focus_areas){ [] }

    let(:mock_response) do
      double('response', body: {
        'candidates' => [
          {
            'content' => {
              'parts' => [
                { 'text' => 'Subject: Test Subject\n\nTest email body' }
              ]
            }
          }
        ]
      }.to_json)
    end

    before do
      # Mock will be set up individually in each test
    end

    it 'returns formatted result with all parameters' do
      allow(described_class).to receive(:post).and_return(mock_response)
      allow(JSON).to receive(:parse).and_return(JSON.parse(mock_response.body))

      result = writer_agent.run(
        search_results,
        recipient: recipient,
        company: company,
        product_info: product_info,
        sender_company: sender_company
      )

      expect(result).to include(
        company: company,
        email: 'Subject: Test Subject\n\nTest email body',
        variants: array_including('Subject: Test Subject\n\nTest email body'),
        recipient: recipient,
        sources: search_results[:sources],
        product_info: product_info,
        sender_company: sender_company
      )
    end

    it 'uses company from search_results when company parameter is nil' do
      result = writer_agent.run(search_results, company: nil)

      expect(result[:company]).to eq(search_results[:company])
    end

    it 'calls build_prompt with correct parameters' do
      # build_prompt is called in a loop for each variant (default 2 variants)
      expect(writer_agent).to receive(:build_prompt).at_least(:once).with(
        company,
        search_results[:sources],
        recipient,
        company,
        product_info,
        sender_company,
        "professional",
        "founder",
        "short",
        "medium",
        "book_call",
        "balanced",
        anything, # variant_index can be 0, 1, or 2
        2, # num_variants
        search_results[:inferred_focus_areas] || []
      )

      writer_agent.run(
        search_results,
        recipient: recipient,
        company: company,
        product_info: product_info,
        sender_company: sender_company
      )
    end

    it 'makes POST request to correct endpoint' do
      expect(described_class).to receive(:post).with(
        "/models/gemini-2.5-flash:generateContent?key=#{api_key}",
        headers: { 'Content-Type' => 'application/json' },
        body: anything
      )

      writer_agent.run(search_results)
    end

    context 'when API response is malformed' do
      it 'returns error message in email field' do
        malformed_response = double('response', body: { 'candidates' => [] }.to_json)
        allow(described_class).to receive(:post).and_return(malformed_response)
        allow(JSON).to receive(:parse).and_return(JSON.parse(malformed_response.body))

        result = writer_agent.run(search_results)

        expect(result[:email]).to eq('Failed to generate email')
      end
    end

    context 'when API response has no candidates' do
      it 'returns error message in email field' do
        no_candidates_response = double('response', body: { 'candidates' => [] }.to_json)
        allow(described_class).to receive(:post).and_return(no_candidates_response)
        allow(JSON).to receive(:parse).and_return(JSON.parse(no_candidates_response.body))

        result = writer_agent.run(search_results)

        expect(result[:email]).to eq('Failed to generate email')
      end
    end

    context 'when API call raises an error' do
      before do
        allow(described_class).to receive(:post).and_raise(StandardError, 'Network error')
      end

      it 'handles error gracefully' do
        result = writer_agent.run(search_results)

        expect(result[:email]).to eq('Error generating email: Network error')
        expect(result[:company]).to eq(search_results[:company])
        expect(result[:sources]).to eq(search_results[:sources])
      end
    end
  end

  describe '#build_prompt' do
    let(:company_name) { 'Test Corp' }
    let(:sources) do
      [
        {
          'title' => 'Test Article 1',
          'url' => 'https://test.com/article1',
          'content' => 'Test content 1'
        },
        {
          'title' => 'Test Article 2',
          'url' => 'https://test.com/article2',
          'content' => 'Test content 2'
        }
      ]
    end
    let(:recipient) { 'John Doe' }
    let(:company) { 'Test Corp' }
    let(:product_info) { 'Our amazing product' }
    let(:sender_company) { 'My Company' }
    let(:focus_areas) { [] }

    it 'builds prompt with recipient' do
      prompt = writer_agent.send(:build_prompt, company_name, sources, recipient, company, product_info, sender_company, "professional", "founder", "short", "medium", "book_call", "balanced", 0, 1, focus_areas)

      expect(prompt).to include("to #{recipient}")
      expect(prompt).to include("at #{company}")
    end

    it 'builds prompt without recipient when nil' do
      prompt = writer_agent.send(:build_prompt, company_name, sources, nil, company, product_info, sender_company, "professional", "founder", "short", "medium", "book_call", "balanced", 0, 1, focus_areas)

      expect(prompt).to include("at #{company}")
      expect(prompt).not_to include("to #{recipient}")
    end

    it 'includes sender company context when provided' do
      prompt = writer_agent.send(:build_prompt, company_name, sources, recipient, company, product_info, sender_company, "professional", "founder", "short", "medium", "book_call", "balanced", 0, 1, focus_areas)

      expect(prompt).to include("CONTEXT ABOUT YOUR COMPANY AND PRODUCT:")
      expect(prompt).to include(sender_company)
    end

    it 'includes product info context when provided' do
      prompt = writer_agent.send(:build_prompt, company_name, sources, recipient, company, product_info, sender_company, "professional", "founder", "short", "medium", "book_call", "balanced", 0, 1, focus_areas)

      expect(prompt).to include(product_info)
    end

    it 'includes sources when available' do
      prompt = writer_agent.send(:build_prompt, company_name, sources, recipient, company, product_info, sender_company, "professional", "founder", "short", "medium", "book_call", "balanced", 0, 1, focus_areas)

      expect(prompt).to include("Use the following real-time research sources")
      expect(prompt).to include("Source 1:")
      expect(prompt).to include("Title: Test Article 1")
      expect(prompt).to include("URL: https://test.com/article1")
      expect(prompt).to include("Content: Test content 1")
    end

    it 'handles empty sources gracefully' do
      prompt = writer_agent.send(:build_prompt, company_name, [], recipient, company, product_info, sender_company, "professional", "founder", "short", "medium", "book_call", "balanced", 0, 1, focus_areas)

      expect(prompt).to include("Limited sources found")
      expect(prompt).not_to include("Use the following real-time research sources")
    end

    it 'includes critical requirements' do
      prompt = writer_agent.send(:build_prompt, company_name, sources, recipient, company, product_info, sender_company, "professional", "founder", "short", "medium", "book_call", "balanced", 0, 1, [])

      expect(prompt).to include("CRITICAL REQUIREMENTS:")
      expect(prompt).to include("Subject Line:")
      expect(prompt).to include("Opening:")
      expect(prompt).to include("Value Proposition:")
      expect(prompt).to include("Personalization Level:") # Changed from "Personalization:"
      expect(prompt).to include("Tone:")
      expect(prompt).to include("Call-to-Action:")
      expect(prompt).to include("Length:")
      expect(prompt).to include("Spam Prevention:")
    end

    it 'includes output format instructions' do
      prompt = writer_agent.send(:build_prompt, company_name, sources, recipient, company, product_info, sender_company, "professional", "founder", "short", "medium", "book_call", "balanced", 0, 1, focus_areas)
      expect(prompt).to include("Format the output as:")
      expect(prompt).to include("Subject: [email subject]")
      expect(prompt).to include("[email body]")
    end

    it 'handles sources with missing fields' do
      incomplete_sources = [
        { 'title' => 'Test Article' },
        { 'url' => 'https://test.com' },
        { 'content' => 'Test content' }
      ]

      prompt = writer_agent.send(:build_prompt, company_name, incomplete_sources, recipient, company, product_info, sender_company, "professional", "founder", "short", "medium", "book_call", "balanced", 0, 1, focus_areas)

      expect(prompt).to include("Title: Test Article")
      expect(prompt).to include("URL: https://test.com")
      expect(prompt).to include("Content: Test content")
    end
  end

  describe 'HTTParty configuration' do
    it 'includes HTTParty module' do
      expect(described_class.included_modules).to include(HTTParty)
    end

    it 'sets correct base_uri' do
      expect(described_class.base_uri).to eq('https://generativelanguage.googleapis.com/v1beta')
    end
  end
end
