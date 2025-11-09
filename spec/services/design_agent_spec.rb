require 'rails_helper'

RSpec.describe DesignAgent, type: :service do
  let(:api_key) { 'test-gemini-key' }
  let(:design_agent) { described_class.new(api_key: api_key) }

  describe '#initialize' do
    context 'with valid API key' do
      it 'initializes successfully' do
        expect(design_agent).to be_a(DesignAgent)
      end

      it 'sets default model' do
        expect(design_agent.instance_variable_get(:@model)).to eq('gemini-2.5-flash')
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
    let(:writer_output) do
      {
        email: "Subject: Test Subject\n\nHi John,\n\nThis is a test email about Test Corp. We have an amazing product that can help you.",
        company: 'Test Corp',
        recipient: 'John Doe'
      }
    end

    let(:mock_response) do
      double('response', body: {
        'candidates' => [
          {
            'content' => {
              'parts' => [
                { 'text' => "Subject: Test Subject\n\nHi **John**,\n\nThis is a test email about **Test Corp**. We have an *amazing* product that can help you." }
              ]
            }
          }
        ]
      }.to_json)
    end

    it 'returns formatted result with markdown formatting' do
      allow(described_class).to receive(:post).and_return(mock_response)
      allow(JSON).to receive(:parse).and_return(JSON.parse(mock_response.body))

      result = design_agent.run(writer_output)

      expect(result).to include(
        company: 'Test Corp',
        recipient: 'John Doe',
        original_email: writer_output[:email]
      )
      expect(result[:formatted_email]).to include('**John**')
      expect(result[:formatted_email]).to include('**Test Corp**')
      expect(result[:formatted_email]).to include('*amazing*')
    end

    it 'handles empty email content gracefully' do
      empty_output = { email: '', company: 'Test Corp', recipient: 'John Doe' }

      result = design_agent.run(empty_output)

      expect(result[:email]).to eq('')
      expect(result[:formatted_email]).to eq('')
      expect(result[:company]).to eq('Test Corp')
    end

    it 'handles nil email content gracefully' do
      nil_output = { email: nil, company: 'Test Corp' }

      result = design_agent.run(nil_output)

      expect(result[:email]).to be_nil
      expect(result[:formatted_email]).to be_nil
    end

    it 'handles string keys in writer_output' do
      string_key_output = {
        'email' => "Subject: Test\n\nHello",
        'company' => 'Test Corp',
        'recipient' => 'John'
      }

      allow(described_class).to receive(:post).and_return(mock_response)
      allow(JSON).to receive(:parse).and_return(JSON.parse(mock_response.body))

      result = design_agent.run(string_key_output)

      expect(result[:company]).to eq('Test Corp')
      expect(result[:recipient]).to eq('John')
    end

    it 'makes POST request to correct endpoint' do
      expect(described_class).to receive(:post).with(
        "/models/gemini-2.5-flash:generateContent?key=#{api_key}",
        headers: { 'Content-Type' => 'application/json' },
        body: anything
      )

      design_agent.run(writer_output)
    end

    it 'uses correct temperature and max tokens' do
      expect(described_class).to receive(:post).with(
        anything,
        hash_including(
          body: hash_including(
            generationConfig: hash_including(
              temperature: 0.3,
              maxOutputTokens: 8192
            )
          )
        )
      )

      design_agent.run(writer_output)
    end

    context 'when API response is malformed' do
      it 'returns original email when response is invalid' do
        malformed_response = double('response', body: { 'candidates' => [] }.to_json)
        allow(described_class).to receive(:post).and_return(malformed_response)
        allow(JSON).to receive(:parse).and_return(JSON.parse(malformed_response.body))

        result = design_agent.run(writer_output)

        expect(result[:formatted_email]).to eq(writer_output[:email])
        expect(result[:original_email]).to eq(writer_output[:email])
      end
    end

    context 'when API call raises an error' do
      before do
        allow(described_class).to receive(:post).and_raise(StandardError, 'Network error')
      end

      it 'handles error gracefully' do
        result = design_agent.run(writer_output)

        expect(result[:email]).to eq(writer_output[:email])
        expect(result[:formatted_email]).to eq(writer_output[:email])
        expect(result[:error]).to eq('Network error')
        expect(result[:company]).to eq(writer_output[:company])
        expect(result[:recipient]).to eq(writer_output[:recipient])
      end
    end
  end

  describe '#build_prompt' do
    let(:email_content) { "Subject: Test\n\nHi John, this is a test email." }
    let(:company) { 'Test Corp' }
    let(:recipient) { 'John Doe' }

    it 'includes markdown formatting instructions' do
      prompt = design_agent.send(:build_prompt, email_content, company, recipient)

      expect(prompt).to include('**bold**')
      expect(prompt).to include('*italic*')
      expect(prompt).to include('~~strikethrough~~')
      expect(prompt).to include('`code`')
      expect(prompt).to include('[link text](url)')
      expect(prompt).to include('> quote')
    end

    it 'includes company information when provided' do
      prompt = design_agent.send(:build_prompt, email_content, company, recipient)

      expect(prompt).to include("Company: #{company}")
    end

    it 'includes recipient information when provided' do
      prompt = design_agent.send(:build_prompt, email_content, company, recipient)

      expect(prompt).to include("Recipient: #{recipient}")
    end

    it 'handles nil company gracefully' do
      prompt = design_agent.send(:build_prompt, email_content, nil, recipient)

      expect(prompt).not_to include('Company:')
    end

    it 'handles nil recipient gracefully' do
      prompt = design_agent.send(:build_prompt, email_content, company, nil)

      expect(prompt).not_to include('Recipient:')
    end

    it 'includes email content to format' do
      prompt = design_agent.send(:build_prompt, email_content, company, recipient)

      expect(prompt).to include('Email content to format:')
      expect(prompt).to include(email_content)
    end

    it 'instructs to keep Subject line unchanged' do
      prompt = design_agent.send(:build_prompt, email_content, company, recipient)

      expect(prompt).to include('Keep the Subject line unchanged')
    end

    it 'instructs to maintain structure' do
      prompt = design_agent.send(:build_prompt, email_content, company, recipient)

      expect(prompt).to include('Maintain all line breaks and structure')
      expect(prompt).to include('Do not change the content, only add formatting')
    end

    it 'instructs to be selective with formatting' do
      prompt = design_agent.send(:build_prompt, email_content, company, recipient)

      expect(prompt).to include('Be selective - don\'t over-format')
    end
  end

  describe 'HTTParty configuration' do
    it 'includes HTTParty module' do
      expect(DesignAgent.included_modules).to include(HTTParty)
    end

    it 'sets correct base_uri' do
      expect(DesignAgent.base_uri).to eq('https://generativelanguage.googleapis.com/v1beta')
    end
  end
end
