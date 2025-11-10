require 'rails_helper'

RSpec.describe Orchestrator, type: :service do
  let(:gemini_api_key) { 'test-gemini-key' }
  let(:tavily_api_key) { 'test-tavily-key' }
  let(:orchestrator) { described_class.new(gemini_api_key: gemini_api_key, tavily_api_key: tavily_api_key) }

  let(:mock_search_results) do
    {
      domain: {
        domain: 'Test Corp',
        sources: [
          {
            'title' => 'Test Article',
            'url' => 'https://test.com/article',
            'content' => 'Test content'
          }
        ]
      },
      recipient: {
        name: 'John Doe',
        sources: []
      },
      sources: [
        {
          'title' => 'Test Article',
          'url' => 'https://test.com/article',
          'content' => 'Test content'
        }
      ]
    }
  end

  let(:mock_writer_output) do
    {
      company: 'Test Corp',
      email: 'Subject: Test Subject\n\nTest email body',
      recipient: 'John Doe',
      sources: mock_search_results[:sources]
    }
  end

  let(:mock_critique_result) do
    { 'critique' => nil }
  end

  before do
    # Mock the agent services
    allow_any_instance_of(Agents::SearchAgent).to receive(:run).and_return(mock_search_results)
    allow_any_instance_of(Agents::WriterAgent).to receive(:run).and_return(mock_writer_output)
    allow_any_instance_of(Agents::CritiqueAgent).to receive(:run).and_return(mock_critique_result)
  end

  describe '#initialize' do
    it 'initializes with API keys' do
      expect(orchestrator).to be_a(Orchestrator)
    end

    it 'creates SearchAgent instance' do
      expect(orchestrator.instance_variable_get(:@search_agent)).to be_a(Agents::SearchAgent)
    end

    it 'creates WriterAgent instance' do
      expect(orchestrator.instance_variable_get(:@writer_agent)).to be_a(Agents::WriterAgent)
    end

    it 'creates CritiqueAgent instance' do
      expect(orchestrator.instance_variable_get(:@critique_agent)).to be_a(Agents::CritiqueAgent)
    end
  end

  describe '#run' do
    let(:company_name) { 'Test Corp' }
    let(:recipient) { 'John Doe' }
    let(:product_info) { 'Our amazing product' }
    let(:sender_company) { 'My Company' }

    it 'returns complete email campaign with all components' do
      result = orchestrator.run(
        company_name,
        recipient: recipient,
        product_info: product_info,
        sender_company: sender_company
      )

      expect(result).to include(
        company: company_name,
        recipient: recipient,
        email: 'Subject: Test Subject\n\nTest email body',
        critique: nil,
        sources: mock_search_results[:sources],
        product_info: product_info,
        sender_company: sender_company
      )
    end

    it 'calls SearchAgent with company name' do
      expect_any_instance_of(Agents::SearchAgent).to receive(:run).with(company_name, recipient: nil)

      orchestrator.run(company_name)
    end

    it 'calls WriterAgent with search results and parameters' do
      expect_any_instance_of(Agents::WriterAgent).to receive(:run).with(
        mock_search_results,
        recipient: recipient,
        company: company_name,
        product_info: product_info,
        sender_company: sender_company
      )

      orchestrator.run(
        company_name,
        recipient: recipient,
        product_info: product_info,
        sender_company: sender_company
      )
    end

    it 'calls CritiqueAgent with formatted input' do
      expect_any_instance_of(Agents::CritiqueAgent).to receive(:run).with(
        hash_including(
          'email_content' => 'Subject: Test Subject\n\nTest email body',
          'number_of_revisions' => 1
        )
      )

      orchestrator.run(company_name)
    end

    it 'outputs progress information' do
      expect {
        orchestrator.run(company_name)
      }.to output(/Starting pipeline/).to_stdout
    end

    context 'when recipient is nil' do
      it 'shows "General" as recipient' do
        expect {
          orchestrator.run(company_name)
        }.to output(/Recipient: General/).to_stdout
      end
    end

    context 'when sender_company is nil' do
      it 'shows "Not specified" as sender company' do
        expect {
          orchestrator.run(company_name)
        }.to output(/Your Company: Not specified/).to_stdout
      end
    end

    context 'when critique returns feedback' do
      let(:critique_feedback) { 'This email needs improvement.' }
      let(:mock_critique_with_feedback) { { 'critique' => critique_feedback } }

      before do
        allow_any_instance_of(Agents::CritiqueAgent).to receive(:run).and_return(mock_critique_with_feedback)
      end

      it 'shows critique feedback and breaks loop' do
        expect {
          orchestrator.run(company_name)
        }.to output(/CritiqueAgent Feedback: #{critique_feedback[0..120]}/).to_stdout
      end

      it 'returns critique in result' do
        result = orchestrator.run(company_name)

        expect(result[:critique]).to eq(critique_feedback)
      end
    end

    context 'when critique returns nil (approved)' do
      it 'shows approval message' do
        expect {
          orchestrator.run(company_name)
        }.to output(/CritiqueAgent: Email approved ✅/).to_stdout
      end

      it 'returns nil critique in result' do
        result = orchestrator.run(company_name)

        expect(result[:critique]).to be_nil
      end
    end

    context 'with minimal parameters' do
      it 'works with only company name' do
        result = orchestrator.run(company_name)

        expect(result[:company]).to eq(company_name)
        expect(result[:recipient]).to be_nil
        expect(result[:product_info]).to be_nil
        expect(result[:sender_company]).to be_nil
      end
    end

    context 'when search results are empty' do
      let(:empty_search_results) { { domain: { domain: 'Test Corp', sources: [] }, recipient: { name: nil, sources: [] }, sources: [] } }

      before do
        allow_any_instance_of(Agents::SearchAgent).to receive(:run).and_return(empty_search_results)
      end

      it 'handles empty sources gracefully' do
        result = orchestrator.run(company_name)

        expect(result[:sources]).to eq([])
      end
    end

    context 'when writer output is malformed' do
      let(:malformed_writer_output) { { company: 'Test Corp', email: nil } }

      before do
        allow_any_instance_of(Agents::WriterAgent).to receive(:run).and_return(malformed_writer_output)
      end

      it 'handles malformed output gracefully' do
        result = orchestrator.run(company_name)

        expect(result[:email]).to eq('')
      end
    end
  end

  describe '.run' do
    let(:company_name) { 'Test Corp' }

    it 'creates new instance and calls run' do
      expect(described_class).to receive(:new).with(
        gemini_api_key: gemini_api_key,
        tavily_api_key: tavily_api_key
      ).and_return(orchestrator)

      expect(orchestrator).to receive(:run).with(
        company_name,
        recipient: nil,
        product_info: nil,
        sender_company: nil
      )

      described_class.run(company_name, gemini_api_key: gemini_api_key, tavily_api_key: tavily_api_key)
    end

    it 'passes all parameters to instance run method' do
      recipient = 'John Doe'
      product_info = 'Our product'
      sender_company = 'My Company'

      # Mock the new method to return our orchestrator instance
      allow(described_class).to receive(:new).and_return(orchestrator)
      expect(orchestrator).to receive(:run).with(
        company_name,
        recipient: recipient,
        product_info: product_info,
        sender_company: sender_company
      )

      described_class.run(
        company_name,
        gemini_api_key: gemini_api_key,
        tavily_api_key: tavily_api_key,
        recipient: recipient,
        product_info: product_info,
        sender_company: sender_company
      )
    end
  end

  describe 'agent initialization' do
    it 'initializes SearchAgent with tavily API key' do
      expect(Agents::SearchAgent).to receive(:new).with(api_key: tavily_api_key)

      described_class.new(gemini_api_key: gemini_api_key, tavily_api_key: tavily_api_key)
    end

    it 'initializes WriterAgent with gemini API key' do
      expect(Agents::WriterAgent).to receive(:new).with(api_key: gemini_api_key)

      described_class.new(gemini_api_key: gemini_api_key, tavily_api_key: tavily_api_key)
    end

    it 'initializes CritiqueAgent with gemini API key' do
      expect(Agents::CritiqueAgent).to receive(:new).with(api_key: gemini_api_key)

      described_class.new(gemini_api_key: gemini_api_key, tavily_api_key: tavily_api_key)
    end
  end
end
