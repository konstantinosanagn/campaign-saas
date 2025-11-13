require 'rails_helper'

RSpec.describe Orchestrator do
  let(:gemini_api_key) { 'test-gemini-key' }
  let(:tavily_api_key) { 'test-tavily-key' }
  let(:search_agent) { instance_double(Agents::SearchAgent) }
  let(:writer_agent) { instance_double(Agents::WriterAgent) }
  let(:critique_agent) { instance_double(Agents::CritiqueAgent) }

  let(:orchestrator) do
    described_class.new(
      gemini_api_key: gemini_api_key,
      tavily_api_key: tavily_api_key,
      search_agent: search_agent,
      writer_agent: writer_agent,
      critique_agent: critique_agent
    )
  end

  describe '#initialize' do
    context 'with custom agents' do
      it 'uses provided agents' do
        expect(orchestrator.instance_variable_get(:@search_agent)).to eq(search_agent)
        expect(orchestrator.instance_variable_get(:@writer_agent)).to eq(writer_agent)
        expect(orchestrator.instance_variable_get(:@critique_agent)).to eq(critique_agent)
      end
    end

    context 'without custom agents' do
      before do
        allow(ENV).to receive(:fetch).with('GEMINI_API_KEY').and_return('env-gemini-key')
        allow(ENV).to receive(:fetch).with('TAVILY_API_KEY').and_return('env-tavily-key')
      end

      it 'creates new agent instances' do
        orchestrator = described_class.new
        expect(orchestrator.instance_variable_get(:@search_agent)).to be_a(Agents::SearchAgent)
        expect(orchestrator.instance_variable_get(:@writer_agent)).to be_a(Agents::WriterAgent)
        expect(orchestrator.instance_variable_get(:@critique_agent)).to be_a(Agents::CritiqueAgent)
      end
    end
  end

  describe '#run' do
    let(:company_name) { 'Test Corp' }
    let(:recipient) { 'John Doe' }
    let(:product_info) { 'Test Product' }
    let(:sender_company) { 'My Company' }

    let(:search_results) do
      {
        inferred_focus_areas: ['AI', 'Cloud'],
        personalization_signals: {
          company: [{ title: 'Company News', url: 'http://example.com' }],
          recipient: [{ title: 'Recipient News', url: 'http://example.com/recipient' }]
        }
      }
    end

    let(:writer_output) do
      {
        email: 'Subject: Test Email\n\nHello, this is a test email.'
      }
    end

    let(:critique_result) do
      {
        'critique' => nil
      }
    end

    before do
      allow(search_agent).to receive(:run).and_return(search_results)
      allow(writer_agent).to receive(:run).and_return(writer_output)
      allow(critique_agent).to receive(:run).and_return(critique_result)
      allow($stdout).to receive(:puts) # Suppress output
    end

    it 'calls search agent with correct parameters' do
      expect(search_agent).to receive(:run).with(
        company: company_name,
        recipient_name: recipient,
        job_title: nil,
        email: nil,
        tone: nil,
        persona: nil,
        goal: nil
      )
      orchestrator.run(company_name, recipient: recipient)
    end

    it 'calls writer agent with search results' do
      expect(writer_agent).to receive(:run).with(
        {
          company: company_name,
          inferred_focus_areas: search_results[:inferred_focus_areas],
          sources: search_results.dig(:personalization_signals, :company)
        },
        recipient: recipient,
        company: company_name,
        product_info: nil,
        sender_company: nil
      )
      orchestrator.run(company_name, recipient: recipient)
    end

    it 'calls critique agent with email content' do
      expect(critique_agent).to receive(:run).with(
        hash_including(
          'email_content' => writer_output[:email],
          'number_of_revisions' => 1
        )
      )
      orchestrator.run(company_name, recipient: recipient)
    end

    it 'returns complete result with all components' do
      result = orchestrator.run(company_name, recipient: recipient, product_info: product_info, sender_company: sender_company)

      expect(result[:company]).to eq(company_name)
      expect(result[:recipient]).to eq(recipient)
      expect(result[:email]).to eq(writer_output[:email])
      expect(result[:critique]).to be_nil
      expect(result[:sources]).to be_an(Array)
      expect(result[:inferred_focus_areas]).to eq(search_results[:inferred_focus_areas])
      expect(result[:product_info]).to eq(product_info)
      expect(result[:sender_company]).to eq(sender_company)
    end

    context 'when recipient is a hash' do
      let(:recipient_hash) do
        {
          name: 'John Doe',
          job_title: 'CEO',
          email: 'john@example.com',
          tone: 'professional',
          persona: 'executive',
          goal: 'book_call'
        }
      end

      it 'extracts recipient fields correctly' do
        expect(search_agent).to receive(:run).with(
          company: company_name,
          recipient_name: 'John Doe',
          job_title: 'CEO',
          email: 'john@example.com',
          tone: 'professional',
          persona: 'executive',
          goal: 'book_call'
        )
        orchestrator.run(company_name, recipient: recipient_hash)
      end

      it 'uses recipient name in writer agent' do
        expect(writer_agent).to receive(:run).with(
          anything,
          recipient: 'John Doe',
          company: company_name,
          product_info: nil,
          sender_company: nil
        )
        orchestrator.run(company_name, recipient: recipient_hash)
      end
    end

    context 'when recipient is nil' do
      it 'uses "General" as recipient name' do
        expect(search_agent).to receive(:run).with(
          company: company_name,
          recipient_name: nil,
          job_title: nil,
          email: nil,
          tone: nil,
          persona: nil,
          goal: nil
        )
        orchestrator.run(company_name)
      end
    end

    context 'when critique returns feedback' do
      let(:critique_result) do
        {
          'critique' => 'This email needs improvement.'
        }
      end

      it 'includes critique in result' do
        result = orchestrator.run(company_name, recipient: recipient)
        expect(result[:critique]).to eq('This email needs improvement.')
      end

      it 'breaks the loop after first revision' do
        expect(critique_agent).to receive(:run).once
        orchestrator.run(company_name, recipient: recipient)
      end
    end

    context 'when critique returns nil (approved)' do
      it 'breaks the loop' do
        expect(critique_agent).to receive(:run).once.and_return({ 'critique' => nil })
        orchestrator.run(company_name, recipient: recipient)
      end
    end

    context 'when search results have no sources' do
      let(:search_results) do
        {
          inferred_focus_areas: [],
          personalization_signals: {
            company: [],
            recipient: []
          }
        }
      end

      it 'handles empty sources gracefully' do
        result = orchestrator.run(company_name, recipient: recipient)
        expect(result[:sources]).to eq([])
      end
    end

    context 'when writer output has no email' do
      let(:writer_output) { {} }

      it 'uses empty string for email' do
        expect(critique_agent).to receive(:run).with(
          hash_including(
            'email_content' => '',
            'number_of_revisions' => 1
          )
        )
        orchestrator.run(company_name, recipient: recipient)
      end
    end
  end

  describe '.run' do
    let(:company_name) { 'Test Corp' }

    before do
      allow(ENV).to receive(:fetch).with('GEMINI_API_KEY').and_return('env-gemini-key')
      allow(ENV).to receive(:fetch).with('TAVILY_API_KEY').and_return('env-tavily-key')
      allow_any_instance_of(described_class).to receive(:run).and_return({ company: company_name })
      allow($stdout).to receive(:puts)
    end

    it 'creates new instance and calls run' do
      result = described_class.run(company_name)
      expect(result[:company]).to eq(company_name)
    end

    it 'passes all parameters to instance run method' do
      expect_any_instance_of(described_class).to receive(:run).with(
        company_name,
        recipient: 'John',
        product_info: 'Product',
        sender_company: 'Company'
      )
      described_class.run(
        company_name,
        recipient: 'John',
        product_info: 'Product',
        sender_company: 'Company'
      )
    end
  end
end
