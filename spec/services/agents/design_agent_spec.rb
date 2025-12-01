require 'rails_helper'

RSpec.describe Agents::DesignAgent, type: :service do
  let(:api_key) { 'test-gemini-key' }
  let(:design_agent) { described_class.new(api_key: api_key) }

  describe '#initialize' do
    context 'with valid API key' do
      it 'initializes successfully' do
        expect(design_agent).to be_a(described_class)
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

      expect(result[:email]).to eq('')
      expect(result[:formatted_email]).to eq('')
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

    context 'with config parameter' do
      let(:config_with_settings) do
        {
          settings: {
            format: 'formatted',
            allow_bold: true,
            allow_italic: true,
            allow_bullets: true,
            cta_style: 'link',
            font_family: 'system_sans'
          }
        }
      end

      it 'accepts config parameter' do
        allow(described_class).to receive(:post).and_return(mock_response)
        allow(JSON).to receive(:parse).and_return(JSON.parse(mock_response.body))

        expect {
          design_agent.run(writer_output, config: config_with_settings)
        }.not_to raise_error
      end

      it 'extracts settings from config' do
        allow(described_class).to receive(:post).and_return(mock_response)
        allow(JSON).to receive(:parse).and_return(JSON.parse(mock_response.body))

        result = design_agent.run(writer_output, config: config_with_settings)

        expect(result).to include(
          company: 'Test Corp',
          recipient: 'John Doe'
        )
      end

      context 'with plain_text format' do
        let(:plain_text_config) do
          {
            settings: {
              format: 'plain_text'
            }
          }
        end

        it 'builds prompt for plain text format' do
          expect(design_agent).to receive(:build_prompt).with(
            anything,
            anything,
            anything,
            format: 'plain_text',
            allow_bold: true,
            allow_italic: true,
            allow_bullets: true,
            cta_style: 'link',
            font_family: nil
          )

          allow(described_class).to receive(:post).and_return(mock_response)
          allow(JSON).to receive(:parse).and_return(JSON.parse(mock_response.body))

          design_agent.run(writer_output, config: plain_text_config)
        end
      end

      context 'with formatting disabled' do
        let(:no_formatting_config) do
          {
            settings: {
              allow_bold: false,
              allow_italic: false,
              allow_bullets: false
            }
          }
        end

        it 'builds prompt without formatting instructions' do
          prompt = design_agent.send(
            :build_prompt,
            writer_output[:email],
            writer_output[:company],
            writer_output[:recipient],
            format: 'formatted',
            allow_bold: false,
            allow_italic: false,
            allow_bullets: false,
            cta_style: 'link',
            font_family: nil
          )

          expect(prompt).not_to include('**bold**')
          expect(prompt).not_to include('*italic*')
          expect(prompt).not_to include('bullet points')
        end
      end

      context 'with button CTA style' do
        let(:button_cta_config) do
          {
            settings: {
              cta_style: 'button'
            }
          }
        end

        it 'includes button-style CTA instructions' do
          prompt = design_agent.send(
            :build_prompt,
            writer_output[:email],
            writer_output[:company],
            writer_output[:recipient],
            format: 'formatted',
            allow_bold: true,
            allow_italic: true,
            allow_bullets: true,
            cta_style: 'button',
            font_family: nil
          )

          expect(prompt).to include('button-style')
          expect(prompt).not_to include('[link text](url)')
        end
      end

      context 'with serif font family' do
        let(:serif_config) do
          {
            settings: {
              font_family: 'serif'
            }
          }
        end

        it 'includes serif typography guidance' do
          prompt = design_agent.send(
            :build_prompt,
            writer_output[:email],
            writer_output[:company],
            writer_output[:recipient],
            format: 'formatted',
            allow_bold: true,
            allow_italic: true,
            allow_bullets: true,
            cta_style: 'link',
            font_family: 'serif'
          )

          expect(prompt).to include('serif-style emphasis')
        end
      end

      context 'with camelCase settings keys' do
        let(:camel_case_config) do
          {
            settings: {
              'format' => 'formatted',
              'allowBold' => false,
              'allowItalic' => true,
              'allowBullets' => false,
              'ctaStyle' => 'button',
              'fontFamily' => 'serif'
            }
          }
        end

        it 'handles camelCase settings keys' do
          allow(described_class).to receive(:post).and_return(mock_response)
          allow(JSON).to receive(:parse).and_return(JSON.parse(mock_response.body))

          expect(design_agent).to receive(:build_prompt).with(
            anything,
            anything,
            anything,
            hash_including(
              format: 'formatted',
              cta_style: 'button',
              font_family: 'serif'
            )
          ).and_call_original

          design_agent.run(writer_output, config: camel_case_config)
        end
      end

      context 'with snake_case settings keys' do
        let(:snake_case_config) do
          {
            settings: {
              format: 'formatted',
              allow_bold: true,
              allow_italic: false,
              allow_bullets: true,
              cta_style: 'link',
              font_family: 'system_sans'
            }
          }
        end

        it 'handles snake_case settings keys' do
          allow(described_class).to receive(:post).and_return(mock_response)
          allow(JSON).to receive(:parse).and_return(JSON.parse(mock_response.body))

          expect(design_agent).to receive(:build_prompt).with(
            anything,
            anything,
            anything,
            hash_including(
              format: 'formatted',
              cta_style: 'link',
              font_family: 'system_sans'
            )
          ).and_call_original

          design_agent.run(writer_output, config: snake_case_config)
        end
      end
    end

    context 'with input from CRITIQUE output (processed by lead_agent_service)' do
      # Note: The design_agent receives a hash with email, company, and recipient keys
      # The extraction of selected_variant/email_content from CRITIQUE output is handled
      # in lead_agent_service.execute_design_agent, which is tested in lead_agent_service_spec
      let(:design_input_from_critique) do
        {
          email: "Subject: Test Subject\n\nThis is the selected variant from critique.",
          company: 'Test Corp',
          recipient: 'John Doe'
        }
      end

      it 'handles input hash with email, company, and recipient keys' do
        allow(described_class).to receive(:post).and_return(mock_response)
        allow(JSON).to receive(:parse).and_return(JSON.parse(mock_response.body))

        result = design_agent.run(design_input_from_critique)

        expect(result).to include(
          company: 'Test Corp',
          recipient: 'John Doe',
          original_email: design_input_from_critique[:email]
        )
        expect(result[:formatted_email]).to be_present
      end

      it 'handles string keys in design input' do
        design_input_string_keys = {
          'email' => "Subject: Test\n\nHello",
          'company' => 'Test Corp',
          'recipient' => 'John'
        }

        allow(described_class).to receive(:post).and_return(mock_response)
        allow(JSON).to receive(:parse).and_return(JSON.parse(mock_response.body))

        result = design_agent.run(design_input_string_keys)

        expect(result[:company]).to eq('Test Corp')
        expect(result[:recipient]).to eq('John')
      end
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
      captured_body = nil
      allow(described_class).to receive(:post) do |url, options|
        captured_body = JSON.parse(options[:body])
        mock_response
      end

      design_agent.run(writer_output)

      expect(captured_body).to be_present
      expect(captured_body['generationConfig']).to include(
        'temperature' => 0.3,
        'maxOutputTokens' => 8192
      )
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
        expect(result[:error]).to eq('DesignAgent LLM error: StandardError: Network error')
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

    context 'with config settings' do
      it 'builds plain_text format prompt when format is plain_text' do
        prompt = design_agent.send(
          :build_prompt,
          email_content,
          company,
          recipient,
          format: 'plain_text',
          allow_bold: true,
          allow_italic: true,
          allow_bullets: true,
          cta_style: 'link',
          font_family: nil
        )

        expect(prompt).to include('Return the following email content as plain text')
        expect(prompt).to include('Do not add any markdown, HTML, or other formatting')
        expect(prompt).not_to include('**bold**')
        expect(prompt).not_to include('*italic*')
      end

      it 'conditionally includes bold formatting when allow_bold is true' do
        prompt = design_agent.send(
          :build_prompt,
          email_content,
          company,
          recipient,
          format: 'formatted',
          allow_bold: true,
          allow_italic: true,
          allow_bullets: true,
          cta_style: 'link',
          font_family: nil
        )

        expect(prompt).to include('**bold**')
      end

      it 'excludes bold formatting when allow_bold is false' do
        prompt = design_agent.send(
          :build_prompt,
          email_content,
          company,
          recipient,
          format: 'formatted',
          allow_bold: false,
          allow_italic: true,
          allow_bullets: true,
          cta_style: 'link',
          font_family: nil
        )

        expect(prompt).not_to include('**bold**')
      end

      it 'conditionally includes italic formatting when allow_italic is true' do
        prompt = design_agent.send(
          :build_prompt,
          email_content,
          company,
          recipient,
          format: 'formatted',
          allow_bold: true,
          allow_italic: true,
          allow_bullets: true,
          cta_style: 'link',
          font_family: nil
        )

        expect(prompt).to include('*italic*')
      end

      it 'excludes italic formatting when allow_italic is false' do
        prompt = design_agent.send(
          :build_prompt,
          email_content,
          company,
          recipient,
          format: 'formatted',
          allow_bold: true,
          allow_italic: false,
          allow_bullets: true,
          cta_style: 'link',
          font_family: nil
        )

        expect(prompt).not_to include('*italic*')
      end

      it 'conditionally includes bullet points when allow_bullets is true' do
        prompt = design_agent.send(
          :build_prompt,
          email_content,
          company,
          recipient,
          format: 'formatted',
          allow_bold: true,
          allow_italic: true,
          allow_bullets: true,
          cta_style: 'link',
          font_family: nil
        )

        expect(prompt).to include('bullet points')
      end

      it 'excludes bullet points when allow_bullets is false' do
        prompt = design_agent.send(
          :build_prompt,
          email_content,
          company,
          recipient,
          format: 'formatted',
          allow_bold: true,
          allow_italic: true,
          allow_bullets: false,
          cta_style: 'link',
          font_family: nil
        )

        expect(prompt).not_to include('bullet points')
      end

      it 'includes button-style CTA when cta_style is button' do
        prompt = design_agent.send(
          :build_prompt,
          email_content,
          company,
          recipient,
          format: 'formatted',
          allow_bold: true,
          allow_italic: true,
          allow_bullets: true,
          cta_style: 'button',
          font_family: nil
        )

        expect(prompt).to include('button-style')
        expect(prompt).not_to include('[link text](url)')
      end

      it 'includes link CTA when cta_style is link' do
        prompt = design_agent.send(
          :build_prompt,
          email_content,
          company,
          recipient,
          format: 'formatted',
          allow_bold: true,
          allow_italic: true,
          allow_bullets: true,
          cta_style: 'link',
          font_family: nil
        )

        expect(prompt).to include('[link text](url)')
        expect(prompt).not_to include('button-style')
      end

      it 'includes serif typography guidance when font_family is serif' do
        prompt = design_agent.send(
          :build_prompt,
          email_content,
          company,
          recipient,
          format: 'formatted',
          allow_bold: true,
          allow_italic: true,
          allow_bullets: true,
          cta_style: 'link',
          font_family: 'serif'
        )

        expect(prompt).to include('serif-style emphasis')
      end

      it 'includes system sans-serif guidance when font_family is system_sans' do
        prompt = design_agent.send(
          :build_prompt,
          email_content,
          company,
          recipient,
          format: 'formatted',
          allow_bold: true,
          allow_italic: true,
          allow_bullets: true,
          cta_style: 'link',
          font_family: 'system_sans'
        )

        expect(prompt).to include('system sans-serif style')
      end

      it 'does not include font family guidance when font_family is nil' do
        prompt = design_agent.send(
          :build_prompt,
          email_content,
          company,
          recipient,
          format: 'formatted',
          allow_bold: true,
          allow_italic: true,
          allow_bullets: true,
          cta_style: 'link',
          font_family: nil
        )

        expect(prompt).not_to include('serif-style')
        expect(prompt).not_to include('system sans-serif')
      end
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
