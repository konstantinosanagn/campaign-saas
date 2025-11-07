require 'spec_helper'

RSpec.describe Orchestrator do
  let(:orchestrator) { described_class.new }

  describe 'initialization' do
    it 'initializes SearchAgent, WriterAgent, and CritiqueAgent' do
      expect(orchestrator.instance_variable_get(:@search_agent)).to be_a(SearchAgent)
      expect(orchestrator.instance_variable_get(:@writer_agent)).to be_a(WriterAgent)
      expect(orchestrator.instance_variable_get(:@critique_agent)).to be_a(CritiqueAgent)
    end
  end

  describe '#run' do
    let(:company_name) { 'Microsoft' }
    let(:recipient) { 'John Doe' }

    let(:mock_search_results) do
      {
        company: company_name,
        sources: [
          { 'title' => 'Microsoft AI News', 'url' => 'https://example.com', 'content' => 'Article content' }
        ],
        image: 'https://example.com/logo.jpg'
      }
    end

    let(:mock_writer_output) do
      {
        company: company_name,
        email: 'Subject: Hi\n\nEmail content',
        recipient: recipient,
        sources: mock_search_results[:sources],
        image: mock_search_results[:image],
        product_info: 'AI solutions',
        sender_company: 'Acme Corp'
      }
    end

    let(:mock_critique_result) do
      { 'critique' => nil }
    end

    before do
      # Mock SearchAgent
      allow_any_instance_of(SearchAgent).to receive(:run).and_return(mock_search_results)
      
      # Mock WriterAgent
      allow_any_instance_of(WriterAgent).to receive(:run).and_return(mock_writer_output)
      
      # Mock CritiqueAgent
      allow_any_instance_of(CritiqueAgent).to receive(:run).and_return(mock_critique_result)
    end

    context 'with company name only' do
      it 'generates email for target company' do
        result = orchestrator.run(company_name)

        expect(result).to be_a(Hash)
        expect(result[:company]).to eq(company_name)
        expect(result[:email]).to be_a(String)
        expect(result[:sources]).to eq(mock_search_results[:sources])
      end

      it 'calls SearchAgent with company name' do
        expect_any_instance_of(SearchAgent).to receive(:run).with(company_name, recipient: nil)

        orchestrator.run(company_name)
      end

      it 'calls WriterAgent with search results and company name' do
        expect_any_instance_of(WriterAgent).to receive(:run).with(
          mock_search_results,
          recipient: nil,
          company: company_name,
          product_info: nil,
          sender_company: nil
        )

        orchestrator.run(company_name)
      end
    end

    context 'with company name and recipient' do
      it 'generates personalized email for specific recipient' do
        result = orchestrator.run(company_name, recipient: recipient)

        expect(result).to have_key(:recipient)
        expect(result[:recipient]).to eq(recipient)
      end

      it 'passes recipient to WriterAgent' do
        expect_any_instance_of(WriterAgent).to receive(:run).with(
          anything,
          recipient: recipient,
          company: company_name,
          product_info: nil,
          sender_company: nil
        )

        orchestrator.run(company_name, recipient: recipient)
      end
    end

    context 'with product_info and sender_company' do
      let(:product_info) { 'AI automation platform' }
      let(:sender_company) { 'Acme Solutions' }

      it 'passes product_info and sender_company to WriterAgent' do
        expect_any_instance_of(WriterAgent).to receive(:run).with(
          anything,
          recipient: recipient,
          company: company_name,
          product_info: product_info,
          sender_company: sender_company
        )

        orchestrator.run(company_name, recipient: recipient, product_info: product_info, sender_company: sender_company)
      end

      it 'includes product_info and sender_company in output' do
        result = orchestrator.run(company_name, recipient: recipient, product_info: product_info, sender_company: sender_company)

        expect(result[:product_info]).to eq(product_info)
        expect(result[:sender_company]).to eq(sender_company)
      end
    end

    context 'error handling' do
      before do
        allow_any_instance_of(SearchAgent).to receive(:run).and_raise(StandardError.new('Search failed'))
      end

      it 'handles SearchAgent errors gracefully' do
        expect { orchestrator.run(company_name) }.to raise_error(StandardError, 'Search failed')
      end
    end

    context 'with invalid input' do
      it 'handles empty company name' do
        result = orchestrator.run('', recipient: recipient)

        expect(result).to have_key(:company)
        # The orchestrator will still try to process the request
      end

      it 'handles nil values' do
        result = orchestrator.run(company_name, recipient: nil)

        expect(result[:recipient]).to eq(nil)
      end
    end

    context 'integration with agents' do
      it 'maintains data flow through the pipeline' do
        result = orchestrator.run(company_name, recipient: recipient)

        # Verify data flows correctly
        expect(result[:company]).to eq(company_name)
        expect(result[:recipient]).to eq(recipient)
        expect(result[:sources]).to eq(mock_search_results[:sources])
        expect(result[:email]).to eq(mock_writer_output[:email])
      end

      it 'calls CritiqueAgent with email content' do
        expect_any_instance_of(CritiqueAgent).to receive(:run).with(hash_including(
          'email_content' => mock_writer_output[:email]
        ))

        orchestrator.run(company_name, recipient: recipient)
      end
    end
  end

  describe '.run' do
    it 'creates a new instance and calls run' do
      expect_any_instance_of(described_class).to receive(:run).with('Microsoft', any_args)

      described_class.run('Microsoft', recipient: 'John')
    end
  end
end
