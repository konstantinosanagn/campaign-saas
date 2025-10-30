require 'rails_helper'

RSpec.describe CritiqueAgent, type: :service do
  let(:api_key) { 'test-gemini-key' }
  let(:critique_agent) { described_class.new(api_key: api_key) }

  describe '#initialize' do
    context 'with valid API key' do
      it 'initializes successfully' do
        expect(critique_agent).to be_a(CritiqueAgent)
      end

      it 'sets default model' do
        expect(critique_agent.instance_variable_get(:@model)).to eq('gemini-2.5-flash')
      end

      it 'sets headers' do
        expect(critique_agent.instance_variable_get(:@headers)).to eq({ 'Content-Type' => 'application/json' })
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

  describe '#critique' do
    let(:article) do
      {
        'email_content' => 'Subject: Test\n\nThis is a test email.',
        'number_of_revisions' => 0
      }
    end

    let(:mock_response) do
      double('response', parsed_response: {
        'candidates' => [
          {
            'content' => {
              'parts' => [
                { 'text' => 'This email needs improvement.' }
              ]
            }
          }
        ]
      })
    end

    before do
      allow(described_class).to receive(:post).and_return(mock_response)
    end

    it 'returns critique when provided' do
      result = critique_agent.critique(article)

      expect(result).to eq({ 'critique' => 'This email needs improvement.' })
    end

    it 'makes POST request with correct parameters' do
      expect(described_class).to receive(:post).with(
        "/models/gemini-2.5-flash:generateContent?key=#{api_key}",
        headers: { 'Content-Type' => 'application/json' },
        body: anything
      )

      critique_agent.critique(article)
    end

    it 'includes current date in prompt' do
      expect(described_class).to receive(:post) do |_, options|
        body = JSON.parse(options[:body])
        user_content = body['contents'].find { |c| c['role'] == 'user' }['parts'][0]['text']
        expect(user_content).to include(Date.today.strftime('%d/%m/%Y'))
        mock_response
      end

      critique_agent.critique(article)
    end

    it 'includes email content in prompt' do
      expect(described_class).to receive(:post) do |_, options|
        body = JSON.parse(options[:body])
        user_content = body['contents'].find { |c| c['role'] == 'user' }['parts'][0]['text']
        expect(user_content).to include(article['email_content'])
        mock_response
      end

      critique_agent.critique(article)
    end

    context 'when critique is "None"' do
      let(:none_response) do
        double('response', parsed_response: {
          'candidates' => [
            {
              'content' => {
                'parts' => [
                  { 'text' => 'None' }
                ]
              }
            }
          ]
        })
      end

      before do
        allow(described_class).to receive(:post).and_return(none_response)
      end

      it 'returns nil critique' do
        result = critique_agent.critique(article)

        expect(result).to eq({ 'critique' => nil })
      end
    end

    context 'when critique is "none" (case insensitive)' do
      let(:none_response) do
        double('response', parsed_response: {
          'candidates' => [
            {
              'content' => {
                'parts' => [
                  { 'text' => 'none' }
                ]
              }
            }
          ]
        })
      end

      before do
        allow(described_class).to receive(:post).and_return(none_response)
      end

      it 'returns nil critique' do
        result = critique_agent.critique(article)

        expect(result).to eq({ 'critique' => nil })
      end
    end

    context 'when number of revisions is 1' do
      let(:article_with_revisions) do
        {
          'email_content' => 'Subject: Test\n\nThis is a test email.',
          'number_of_revisions' => 1
        }
      end

      it 'returns nil critique to avoid infinite loop' do
        result = critique_agent.critique(article_with_revisions)

        expect(result).to eq({ 'critique' => nil })
      end
    end

    context 'when number of revisions is string "1"' do
      let(:article_with_revisions) do
        {
          'email_content' => 'Subject: Test\n\nThis is a test email.',
          'number_of_revisions' => '1'
        }
      end

      it 'returns nil critique to avoid infinite loop' do
        result = critique_agent.critique(article_with_revisions)

        expect(result).to eq({ 'critique' => nil })
      end
    end

    context 'when response is empty' do
      let(:empty_response) do
        double('response', parsed_response: {
          'candidates' => [
            {
              'content' => {
                'parts' => [
                  { 'text' => '' }
                ]
              }
            }
          ]
        })
      end

      before do
        allow(described_class).to receive(:post).and_return(empty_response)
      end

      it 'returns nil critique' do
        result = critique_agent.critique(article)

        expect(result).to eq({ 'critique' => nil })
      end
    end

    context 'when API call raises an error' do
      before do
        allow(described_class).to receive(:post).and_raise(StandardError, 'Network error')
      end

      it 'handles error gracefully' do
        result = critique_agent.critique(article)

        expect(result).to eq({
          'critique' => nil,
          'error' => 'Network error',
          'detail' => 'Network error'
        })
      end

      it 'logs error message' do
        expect {
          critique_agent.critique(article)
        }.to output(/CritiqueAgent network error: StandardError: Network error/).to_stderr
      end
    end

    context 'when response is malformed' do
      let(:malformed_response) do
        double('response', parsed_response: {})
      end

      before do
        allow(described_class).to receive(:post).and_return(malformed_response)
      end

      it 'returns nil critique' do
        result = critique_agent.critique(article)

        expect(result).to eq({ 'critique' => nil })
      end
    end
  end

  describe '#run' do
    let(:article) do
      {
        'email_content' => 'Subject: Test\n\nThis is a test email.',
        'number_of_revisions' => 0
      }
    end

    let(:mock_response) do
      double('response', parsed_response: {
        'candidates' => [
          {
            'content' => {
              'parts' => [
                { 'text' => 'This email needs improvement.' }
              ]
            }
          }
        ]
      })
    end

    before do
      allow(described_class).to receive(:post).and_return(mock_response)
    end

    it 'merges critique result into article' do
      result = critique_agent.run(article)

      expect(result).to include(
        'email_content' => 'Subject: Test\n\nThis is a test email.',
        'number_of_revisions' => 0,
        'critique' => 'This email needs improvement.'
      )
    end

    it 'calls critique method' do
      expect(critique_agent).to receive(:critique).with(article).and_return({ 'critique' => 'Test critique' })

      result = critique_agent.run(article)

      expect(result['critique']).to eq('Test critique')
    end
  end

  describe 'HTTParty configuration' do
    it 'includes HTTParty module' do
      expect(CritiqueAgent.included_modules).to include(HTTParty)
    end

    it 'sets correct base_uri' do
      expect(CritiqueAgent.base_uri).to eq('https://generativelanguage.googleapis.com/v1beta')
    end
  end
end
