require 'rails_helper'

RSpec.describe Agents::CritiqueAgent, type: :service do
  let(:api_key) { 'test-gemini-key' }
  let(:critique_agent) { described_class.new(api_key: api_key) }

  describe '#initialize' do
    context 'with valid API key' do
      it 'initializes successfully' do
        expect(critique_agent).to be_a(described_class)
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

      expect(result).to include('critique' => 'This email needs improvement.')
      expect(result).to have_key('score')
      expect(result).to have_key('meets_min_score')
    end

    it 'makes POST request with correct parameters' do
      expect(described_class).to receive(:post).with(
        "/models/gemini-2.5-flash:generateContent?key=#{api_key}",
        headers: { 'Content-Type' => 'application/json' },
        body: anything
      )

      critique_agent.critique(article)
    end

    context 'with custom model' do
      let(:custom_model) { 'gemini-pro' }
      let(:custom_agent) { described_class.new(api_key: api_key, model: custom_model) }

      it 'uses custom model in API call' do
        expect(described_class).to receive(:post).with(
          "/models/#{custom_model}:generateContent?key=#{api_key}",
          headers: { 'Content-Type' => 'application/json' },
          body: anything
        )

        custom_agent.critique(article)
      end
    end

    it 'includes model role with correct prompt structure' do
      expect(described_class).to receive(:post) do |_, options|
        body = JSON.parse(options[:body])
        model_content = body['contents'].find { |c| c['role'] == 'model' }['parts'][0]['text']
        expect(model_content).to include("Today's date is")
        expect(model_content).to include(Date.today.strftime('%d/%m/%Y'))
        expect(model_content).to include('You are the Critique Agent in a multi-agent workflow')
        expect(model_content).to include('Readability & Clarity')
        expect(model_content).to include('Engagement & Persuasion')
        expect(model_content).to include('Structural & Stylistic Quality')
        expect(model_content).to include('Brand Alignment & Tone Consistency')
        expect(model_content).to include('Deliverability & Technical Health')
        expect(model_content).to include('return exactly: None')
        expect(model_content).to include('under 150 words')
        mock_response
      end

      critique_agent.critique(article)
    end

    it 'includes user role with only email content' do
      expect(described_class).to receive(:post) do |_, options|
        body = JSON.parse(options[:body])
        user_content = body['contents'].find { |c| c['role'] == 'user' }['parts'][0]['text']
        expect(user_content).to eq(article['email_content'])
        mock_response
      end

      critique_agent.critique(article)
    end

    it 'sends correct structure with model and user roles' do
      expect(described_class).to receive(:post) do |_, options|
        body = JSON.parse(options[:body])
        expect(body['contents'].length).to eq(2)
        expect(body['contents'][0]['role']).to eq('model')
        expect(body['contents'][1]['role']).to eq('user')
        expect(body['contents'][0]['parts'][0]['text']).to be_a(String)
        expect(body['contents'][1]['parts'][0]['text']).to eq(article['email_content'])
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

        expect(result).to include('critique' => nil)
        expect(result).to include('score' => 10)
        expect(result).to include('meets_min_score' => true)
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

        expect(result).to include('critique' => nil)
        expect(result).to include('score' => 10)
        expect(result).to include('meets_min_score' => true)
      end
    end

    context 'when number of revisions is 1' do
      let(:article_with_revisions) do
        {
          'email_content' => 'Subject: Test\n\nThis is a test email.',
          'number_of_revisions' => 1
        }
      end

      it 'processes critique normally (revision limit is >= 3)' do
        result = critique_agent.critique(article_with_revisions)

        expect(result).to include('critique' => 'This email needs improvement.')
        expect(result).to have_key('score')
        expect(result).to have_key('meets_min_score')
      end
    end

    context 'when number of revisions is string "1"' do
      let(:article_with_revisions) do
        {
          'email_content' => 'Subject: Test\n\nThis is a test email.',
          'number_of_revisions' => '1'
        }
      end

      it 'processes critique normally (revision limit is >= 3)' do
        result = critique_agent.critique(article_with_revisions)

        expect(result).to include('critique' => 'This email needs improvement.')
        expect(result).to have_key('score')
        expect(result).to have_key('meets_min_score')
      end
    end

    context 'when number of revisions is 2' do
      let(:article_with_revisions) do
        {
          'email_content' => 'Subject: Test\n\nThis is a test email.',
          'number_of_revisions' => 2
        }
      end

      it 'processes critique normally (revision limit is >= 3)' do
        result = critique_agent.critique(article_with_revisions)

        expect(result).to include('critique' => 'This email needs improvement.')
        expect(result).to have_key('score')
        expect(result).to have_key('meets_min_score')
      end
    end

    context 'when number of revisions is string "2"' do
      let(:article_with_revisions) do
        {
          'email_content' => 'Subject: Test\n\nThis is a test email.',
          'number_of_revisions' => '2'
        }
      end

      it 'processes critique normally (revision limit is >= 3)' do
        result = critique_agent.critique(article_with_revisions)

        expect(result).to include('critique' => 'This email needs improvement.')
        expect(result).to have_key('score')
        expect(result).to have_key('meets_min_score')
      end
    end

    context 'when number of revisions is 3' do
      let(:article_with_revisions) do
        {
          'email_content' => 'Subject: Test\n\nThis is a test email.',
          'number_of_revisions' => 3
        }
      end

      it 'returns nil critique to avoid infinite loop' do
        result = critique_agent.critique(article_with_revisions)

        expect(result).to include('critique' => nil)
        expect(result).to include('score' => 10)
        expect(result).to include('meets_min_score' => true)
      end
    end

    context 'when number of revisions is string "3"' do
      let(:article_with_revisions) do
        {
          'email_content' => 'Subject: Test\n\nThis is a test email.',
          'number_of_revisions' => '3'
        }
      end

      it 'returns nil critique to avoid infinite loop' do
        result = critique_agent.critique(article_with_revisions)

        expect(result).to include('critique' => nil)
        expect(result).to include('score' => 10)
        expect(result).to include('meets_min_score' => true)
      end
    end

    context 'when number of revisions is greater than 3' do
      let(:article_with_revisions) do
        {
          'email_content' => 'Subject: Test\n\nThis is a test email.',
          'number_of_revisions' => 4
        }
      end

      it 'returns nil critique to avoid infinite loop' do
        result = critique_agent.critique(article_with_revisions)

        expect(result).to include('critique' => nil)
        expect(result).to include('score' => 10)
        expect(result).to include('meets_min_score' => true)
      end
    end

    context 'when number of revisions is missing' do
      let(:article_without_revisions) do
        {
          'email_content' => 'Subject: Test\n\nThis is a test email.'
        }
      end

      it 'processes critique normally' do
        result = critique_agent.critique(article_without_revisions)

        expect(result).to include('critique' => 'This email needs improvement.')
        expect(result).to have_key('score')
        expect(result).to have_key('meets_min_score')
      end
    end

    context 'when email_content is nil' do
      let(:article_with_nil_content) do
        {
          'email_content' => nil,
          'number_of_revisions' => 0
        }
      end

      it 'converts nil to empty string' do
        expect(described_class).to receive(:post) do |_, options|
          body = JSON.parse(options[:body])
          user_content = body['contents'].find { |c| c['role'] == 'user' }['parts'][0]['text']
          expect(user_content).to eq('')
          mock_response
        end

        critique_agent.critique(article_with_nil_content)
      end
    end

    context 'when email_content is not a string' do
      let(:article_with_non_string_content) do
        {
          'email_content' => 12345,
          'number_of_revisions' => 0
        }
      end

      it 'converts to string' do
        expect(described_class).to receive(:post) do |_, options|
          body = JSON.parse(options[:body])
          user_content = body['contents'].find { |c| c['role'] == 'user' }['parts'][0]['text']
          expect(user_content).to eq('12345')
          mock_response
        end

        critique_agent.critique(article_with_non_string_content)
      end
    end

    context 'when email_content is missing' do
      let(:article_without_content) do
        {
          'number_of_revisions' => 0
        }
      end

      it 'converts missing key to empty string' do
        expect(described_class).to receive(:post) do |_, options|
          body = JSON.parse(options[:body])
          user_content = body['contents'].find { |c| c['role'] == 'user' }['parts'][0]['text']
          expect(user_content).to eq('')
          mock_response
        end

        critique_agent.critique(article_without_content)
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

        expect(result).to have_key('critique')
        expect(result['critique']).to be_nil
        expect(result).to have_key('score')
        expect(result['score']).to be_a(Integer)
        expect(result).to have_key('meets_min_score')
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

        expect(result).to have_key('critique')
        expect(result['critique']).to be_nil
        expect(result).to have_key('score')
        expect(result).to have_key('meets_min_score')
      end
    end

    context 'when response text is nil' do
      let(:nil_text_response) do
        double('response', parsed_response: {
          'candidates' => [
            {
              'content' => {
                'parts' => [
                  { 'text' => nil }
                ]
              }
            }
          ]
        })
      end

      before do
        allow(described_class).to receive(:post).and_return(nil_text_response)
      end

      it 'returns nil critique' do
        result = critique_agent.critique(article)

        expect(result).to include('critique' => nil)
        # When text is nil/empty, score is min_score (default 6)
        expect(result['score']).to eq(6)
        expect(result['meets_min_score']).to eq(true)
      end
    end

    context 'when response has no candidates' do
      let(:no_candidates_response) do
        double('response', parsed_response: {
          'candidates' => []
        })
      end

      before do
        allow(described_class).to receive(:post).and_return(no_candidates_response)
      end

      it 'returns nil critique' do
        result = critique_agent.critique(article)

        expect(result).to have_key('critique')
        expect(result['critique']).to be_nil
        expect(result).to have_key('score')
        expect(result).to have_key('meets_min_score')
      end
    end

    context 'when response has no content' do
      let(:no_content_response) do
        double('response', parsed_response: {
          'candidates' => [
            {}
          ]
        })
      end

      before do
        allow(described_class).to receive(:post).and_return(no_content_response)
      end

      it 'returns nil critique' do
        result = critique_agent.critique(article)

        expect(result).to have_key('critique')
        expect(result['critique']).to be_nil
        expect(result).to have_key('score')
        expect(result).to have_key('meets_min_score')
      end
    end

    context 'when response has no parts' do
      let(:no_parts_response) do
        double('response', parsed_response: {
          'candidates' => [
            {
              'content' => {
                'parts' => []
              }
            }
          ]
        })
      end

      before do
        allow(described_class).to receive(:post).and_return(no_parts_response)
      end

      it 'returns nil critique' do
        result = critique_agent.critique(article)

        expect(result).to have_key('critique')
        expect(result['critique']).to be_nil
        expect(result).to have_key('score')
        expect(result).to have_key('meets_min_score')
      end
    end

    context 'when response text has whitespace' do
      let(:whitespace_response) do
        double('response', parsed_response: {
          'candidates' => [
            {
              'content' => {
                'parts' => [
                  { 'text' => '  Valid critique with spaces  ' }
                ]
              }
            }
          ]
        })
      end

      before do
        allow(described_class).to receive(:post).and_return(whitespace_response)
      end

      it 'strips whitespace and returns critique' do
        result = critique_agent.critique(article)

        expect(result).to include('critique' => 'Valid critique with spaces')
        expect(result).to have_key('score')
        expect(result).to have_key('meets_min_score')
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
      expect(result).to have_key('score')
      expect(result).to have_key('meets_min_score')
    end

    it 'calls critique method' do
      expect(critique_agent).to receive(:critique).with(article, config: nil).and_return({ 'critique' => 'Test critique', 'score' => 8, 'meets_min_score' => true })

      result = critique_agent.run(article)

      expect(result['critique']).to eq('Test critique')
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
