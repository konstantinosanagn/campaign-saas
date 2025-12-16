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
        expect(model_content).to include('write exactly: "None"').or include('write exactly: None')
        expect(model_content).to include('under 150 words')
        expect(model_content).to match(/Score:\s*\d+\s*\/?\s*10/i).or include('Score:')
        mock_response
      end

      critique_agent.critique(article)
    end

    it 'does not include min_score_for_send in prompt' do
      config = { 'settings' => { 'min_score_for_send' => 10, 'strictness' => 'moderate' } }

      expect(described_class).to receive(:post) do |_, options|
        body = JSON.parse(options[:body])
        model_content = body['contents'].find { |c| c['role'] == 'model' }['parts'][0]['text']
        expect(model_content).not_to include('min_score_for_send')
        mock_response
      end

      critique_agent.critique(article, config: config)
    end

    it 'does not contain threshold-related words in prompt' do
      expect(described_class).to receive(:post) do |_, options|
        body = JSON.parse(options[:body])
        model_content = body['contents'].find { |c| c['role'] == 'model' }['parts'][0]['text']
        # Check for threshold-related words using regex
        threshold_pattern = /\b(threshold|minimum score|must meet|to send)\b/i
        expect(model_content).not_to match(threshold_pattern)
        mock_response
      end

      critique_agent.critique(article)
    end

    it 'explicitly instructs score 0-10 format' do
      expect(described_class).to receive(:post) do |_, options|
        body = JSON.parse(options[:body])
        model_content = body['contents'].find { |c| c['role'] == 'model' }['parts'][0]['text']
        expect(model_content).to match(/Score:\s*X\s*\/?\s*10/i).or match(/score\s*0-10/i).or match(/Score:\s*\d+\s*\/?\s*10/i)
        mock_response
      end

      critique_agent.critique(article)
    end

    context 'strictness guidance' do
      it 'uses lenient guidance when strictness is lenient' do
        config = { 'settings' => { 'strictness' => 'lenient' } }

        expect(described_class).to receive(:post) do |_, options|
          body = JSON.parse(options[:body])
          model_content = body['contents'].find { |c| c['role'] == 'model' }['parts'][0]['text']
          expect(model_content).to include('Be lenient - only flag extreme issues. Focus on major problems that would significantly impact email effectiveness.')
          mock_response
        end

        critique_agent.critique(article, config: config)
      end

      it 'uses moderate guidance when strictness is moderate' do
        config = { 'settings' => { 'strictness' => 'moderate' } }

        expect(described_class).to receive(:post) do |_, options|
          body = JSON.parse(options[:body])
          model_content = body['contents'].find { |c| c['role'] == 'model' }['parts'][0]['text']
          expect(model_content).to include('Enforce basic quality & tone standards. Flag issues that would reduce email effectiveness or professionalism.')
          mock_response
        end

        critique_agent.critique(article, config: config)
      end

      it 'uses strict guidance when strictness is strict' do
        config = { 'settings' => { 'strictness' => 'strict' } }

        expect(described_class).to receive(:post) do |_, options|
          body = JSON.parse(options[:body])
          model_content = body['contents'].find { |c| c['role'] == 'model' }['parts'][0]['text']
          expect(model_content).to include('Be strict - require strong personalization & adherence to best practices. Flag any issues that could be improved.')
          mock_response
        end

        critique_agent.critique(article, config: config)
      end

      it 'falls back to default guidance when strictness is unknown' do
        config = { 'settings' => { 'strictness' => 'unknown_value' } }

        expect(described_class).to receive(:post) do |_, options|
          body = JSON.parse(options[:body])
          model_content = body['contents'].find { |c| c['role'] == 'model' }['parts'][0]['text']
          expect(model_content).to include('Enforce basic quality & tone standards.')
          mock_response
        end

        critique_agent.critique(article, config: config)
      end
    end

    context 'when article contains variants' do
      it 'delegates to critique_and_select_variant when variants present and selection not none' do
        variants = [ 'A', 'B' ]
        article_with_variants = { 'variants' => variants }

        expected_return = {
          'critique' => 'Selected variant critique',
          'score' => 9,
          'meets_min_score' => true,
          'selected_variant_index' => 1,
          'selected_variant' => 'B',
          'all_variants_critiques' => []
        }

        expect(critique_agent).to receive(:critique_and_select_variant).with(variants, nil, 'highest_overall_score', anything, anything).and_return(expected_return)

        result = critique_agent.critique(article_with_variants)

        expect(result).to eq(expected_return)
      end
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

        expect(result['critique']).to be_nil
        expect(result['meets_min_score']).to eq(true)
        expect(result['score']).to be >= 6  # Score should meet minimum threshold
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

        expect(result['critique']).to be_nil
        expect(result['meets_min_score']).to eq(true)
        expect(result['score']).to be >= 6  # Score should meet minimum threshold
      end
    end

    context 'when number of revisions is below the max threshold' do
      let(:article_with_revisions) do
        {
          'email_content' => 'Subject: Test\n\nThis is a test email.',
          'number_of_revisions' => 1
        }
      end

      it 'processes critique normally' do
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

      it 'processes critique normally' do
        result = critique_agent.critique(article_with_revisions)

        expect(result).to include('critique' => 'This email needs improvement.')
        expect(result).to have_key('score')
        expect(result).to have_key('meets_min_score')
      end
    end

    context 'when number of revisions uses symbol key' do
      let(:article_with_symbol_key) do
        {
          'email_content' => 'Subject: Test\n\nThis is a test email.',
          number_of_revisions: 1
        }
      end

      it 'processes critique normally' do
        result = critique_agent.critique(article_with_symbol_key)

        expect(result).to include('critique' => 'This email needs improvement.')
        expect(result).to include('score')
        expect(result).to include('meets_min_score')
      end
    end

    context 'when number of revisions reaches the maximum attempts' do
      let(:article_with_revisions) do
        {
          'email_content' => 'Subject: Test\n\nThis is a test email.',
          'number_of_revisions' => 3
        }
      end

      it 'returns nil critique to avoid infinite loop' do
        result = critique_agent.critique(article_with_revisions)

        expect(result['critique']).to be_nil
        # Score may vary, but critique should be nil to stop the loop
        expect(result).to have_key('score')
      end
    end

    context 'when number of revisions reaches the maximum attempts as string' do
      let(:article_with_revisions) do
        {
          'email_content' => 'Subject: Test\n\nThis is a test email.',
          'number_of_revisions' => '3'
        }
      end

      it 'returns nil critique to avoid infinite loop' do
        result = critique_agent.critique(article_with_revisions)

        expect(result['critique']).to be_nil
        # Score may vary, but critique should be nil to stop the loop
        expect(result).to have_key('score')
      end
    end

    context 'when number of revisions reaches the maximum attempts with symbol key' do
      let(:article_with_symbol_key) do
        {
          'email_content' => 'Subject: Test\n\nThis is a test email.',
          number_of_revisions: 3
        }
      end

      it 'returns nil critique to avoid infinite loop' do
        result = critique_agent.critique(article_with_symbol_key)

        expect(result['critique']).to be_nil
        expect(result['meets_min_score']).to eq(false)
        expect(result['score']).to be_a(Integer) # Score may vary, but should be present
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

        expect(result).to include('critique' => nil)
        expect(result).to have_key('score')
        expect(result).to have_key('meets_min_score')
      end
    end

    context 'when API call raises an error' do
      before do
        allow(described_class).to receive(:post).and_raise(StandardError, 'Network error')
      end

      it 'handles error gracefully' do
        result = critique_agent.critique(article)

        expect(result['critique']).to be_nil
        expect(result['error']).to eq('Network error')
        expect(result['detail']).to eq('Network error')
        expect(result['retryable']).to be true
        expect(result['error_type']).to eq('network')
        expect(result['provider']).to eq('gemini')
      end

      it 'logs error message' do
        expect {
          critique_agent.critique(article)
        }.to output(/CritiqueAgent network error: StandardError: Network error/).to_stderr
      end
    end

    context 'when response is malformed' do
      let(:malformed_response) do
        double('response', parsed_response: {}, headers: {}, respond_to?: true)
      end

      before do
        allow(malformed_response).to receive(:respond_to?).with(:code).and_return(false)
        allow(malformed_response).to receive(:respond_to?).with(:parsed_response).and_return(true)
        allow(malformed_response).to receive(:respond_to?).with(:headers).and_return(true)
        allow(described_class).to receive(:post).and_return(malformed_response)
      end

      it 'returns nil critique' do
        result = critique_agent.critique(article)

        expect(result).to include('critique' => nil)
        # When text is empty, score is min_score (default 6)
        expect(result['score']).to eq(6)
        expect(result['meets_min_score']).to eq(true)
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
        }, headers: {}, respond_to?: true)
      end

      before do
        allow(nil_text_response).to receive(:respond_to?).with(:code).and_return(false)
        allow(nil_text_response).to receive(:respond_to?).with(:parsed_response).and_return(true)
        allow(nil_text_response).to receive(:respond_to?).with(:headers).and_return(true)
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
        }, headers: {}, respond_to?: true)
      end

      before do
        allow(no_candidates_response).to receive(:respond_to?).with(:code).and_return(false)
        allow(no_candidates_response).to receive(:respond_to?).with(:parsed_response).and_return(true)
        allow(no_candidates_response).to receive(:respond_to?).with(:headers).and_return(true)
        allow(described_class).to receive(:post).and_return(no_candidates_response)
      end

      it 'returns nil critique' do
        result = critique_agent.critique(article)

        expect(result).to include('critique' => nil)
        # When text is empty (no candidates), score is min_score (default 6)
        expect(result['score']).to eq(6)
        expect(result['meets_min_score']).to eq(true)
      end
    end

    context 'when response has no content' do
      let(:no_content_response) do
        double('response', parsed_response: {
          'candidates' => [
            {}
          ]
        }, headers: {}, respond_to?: true)
      end

      before do
        allow(no_content_response).to receive(:respond_to?).with(:code).and_return(false)
        allow(no_content_response).to receive(:respond_to?).with(:parsed_response).and_return(true)
        allow(no_content_response).to receive(:respond_to?).with(:headers).and_return(true)
        allow(described_class).to receive(:post).and_return(no_content_response)
      end

      it 'returns nil critique' do
        result = critique_agent.critique(article)

        expect(result).to include('critique' => nil)
        # When text is empty (no content), score is min_score (default 6)
        expect(result['score']).to eq(6)
        expect(result['meets_min_score']).to eq(true)
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
        }, headers: {}, respond_to?: true)
      end

      before do
        allow(no_parts_response).to receive(:respond_to?).with(:code).and_return(false)
        allow(no_parts_response).to receive(:respond_to?).with(:parsed_response).and_return(true)
        allow(no_parts_response).to receive(:respond_to?).with(:headers).and_return(true)
        allow(described_class).to receive(:post).and_return(no_parts_response)
      end

      it 'returns nil critique' do
        result = critique_agent.critique(article)

        expect(result).to include('critique' => nil)
        # When text is empty (no parts), score is min_score (default 6)
        expect(result['score']).to eq(6)
        expect(result['meets_min_score']).to eq(true)
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

    context 'variant selection logic' do
      it 'selects the variant with the highest overall score' do
        variants = [ 'Variant A', 'Variant B' ]

        # Stub instance critique calls for variants
        expect(critique_agent).to receive(:critique).with(hash_including('email_content' => 'Variant A'), config: nil).and_return({ 'critique' => 'Crit A', 'score' => 4, 'meets_min_score' => false })
        expect(critique_agent).to receive(:critique).with(hash_including('email_content' => 'Variant B'), config: nil).and_return({ 'critique' => 'Crit B', 'score' => 7, 'meets_min_score' => true })

        result = critique_agent.send(:critique_and_select_variant, variants, nil, 'highest_overall_score', 6, 'rewrite_if_bad')

        expect(result['selected_variant_index']).to eq(1)
        expect(result['selected_variant']).to eq('Variant B')
        expect(result['score']).to eq(7)
        expect(result['critique']).to eq('Crit B')
        expect(result['all_variants_critiques'].length).to eq(2)
        expect(result['all_variants_critiques'].first[:variant_index]).to eq(0)
      end

      it 'selects the best variant using highest_personalization_score strategy' do
        variants = [ 'Variant X', 'Variant Y' ]

        expect(critique_agent).to receive(:critique).with(hash_including('email_content' => 'Variant X'), config: nil).and_return({ 'critique' => nil, 'score' => 6, 'meets_min_score' => true })
        expect(critique_agent).to receive(:critique).with(hash_including('email_content' => 'Variant Y'), config: nil).and_return({ 'critique' => 'A long critique to penalize personalization', 'score' => 9, 'meets_min_score' => true })

        result = critique_agent.send(:critique_and_select_variant, variants, nil, 'highest_personalization_score', 6, 'rewrite_if_bad')

        # Because Variant X had nil critique it should be favored by the personalization scoring
        expect(result['selected_variant_index']).to eq(0)
        expect(result['selected_variant']).to eq('Variant X')
        expect(result['all_variants_critiques'].length).to eq(2)
        expect(result['all_variants_critiques'][0][:variant]).to eq('Variant X')
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

  describe 'API error detection and retryable flag' do
    let(:article) { { "email_content" => "Test email" } }

    context 'when API returns error object' do
      it 'detects error and marks 429 as retryable' do
        error_response = double("response",
          code: 429,
          parsed_response: { "error" => { "code" => 429, "message" => "Quota exceeded" } },
          headers: {},
          respond_to?: true
        )
        allow(error_response).to receive(:respond_to?).with(:code).and_return(true)
        allow(error_response).to receive(:respond_to?).with(:parsed_response).and_return(true)
        allow(error_response).to receive(:respond_to?).with(:headers).and_return(true)

        allow(described_class).to receive(:post).and_return(error_response)

        expect {
          critique_agent.critique(article)
        }.to raise_error(StandardError) do |error|
          expect(error.retryable?).to be true
          expect(error.error_code).to eq(429)
          expect(error.message).to include("quota exceeded")
        end
      end

      it 'detects error and marks 500 as retryable' do
        error_response = double("response",
          code: 500,
          parsed_response: { "error" => { "code" => 500, "message" => "Internal server error" } },
          headers: {},
          respond_to?: true
        )
        allow(error_response).to receive(:respond_to?).with(:code).and_return(true)
        allow(error_response).to receive(:respond_to?).with(:parsed_response).and_return(true)
        allow(error_response).to receive(:respond_to?).with(:headers).and_return(true)

        allow(described_class).to receive(:post).and_return(error_response)

        expect {
          critique_agent.critique(article)
        }.to raise_error(StandardError) do |error|
          expect(error.retryable?).to be true
          expect(error.error_code).to eq(500)
        end
      end

      it 'detects error and marks 401 as non-retryable' do
        error_response = double("response",
          code: 401,
          parsed_response: { "error" => { "code" => 401, "message" => "Unauthorized" } },
          headers: {},
          respond_to?: true
        )
        allow(error_response).to receive(:respond_to?).with(:code).and_return(true)
        allow(error_response).to receive(:respond_to?).with(:parsed_response).and_return(true)
        allow(error_response).to receive(:respond_to?).with(:headers).and_return(true)

        allow(described_class).to receive(:post).and_return(error_response)

        expect {
          critique_agent.critique(article)
        }.to raise_error(StandardError) do |error|
          expect(error.retryable?).to be false
          expect(error.error_code).to eq(401)
          expect(error.error_type).to eq("auth")
        end
      end

      it '429 JSON error payload does not attempt score parse; stores all error metadata' do
        error_response = double("response",
          code: 429,
          parsed_response: {
            "error" => {
              "code" => 429,
              "message" => "Quota exceeded",
              "details" => "You have exceeded your API quota"
            }
          },
          headers: {},
          respond_to?: true
        )
        allow(error_response).to receive(:respond_to?).with(:code).and_return(true)
        allow(error_response).to receive(:respond_to?).with(:parsed_response).and_return(true)
        allow(error_response).to receive(:respond_to?).with(:headers).and_return(true)

        allow(described_class).to receive(:post).and_return(error_response)

        expect {
          critique_agent.critique(article)
        }.to raise_error(StandardError) do |error|
          expect(error.retryable?).to be true
          expect(error.error_code).to eq(429)
          expect(error.error_type).to eq("quota")
          expect(error.provider_error).to be_present
          expect(error.provider_error.length).to be <= 500
          # Should not attempt to parse score from error response
          expect(error.message).to include("quota exceeded")
        end
      end
    end

    context 'when API returns errors array' do
      it 'detects error from errors array' do
        error_response = double("response",
          code: 429,
          parsed_response: { "errors" => [ { "code" => 429, "message" => "Quota exceeded" } ] },
          headers: {},
          respond_to?: true
        )
        allow(error_response).to receive(:respond_to?).with(:code).and_return(true)
        allow(error_response).to receive(:respond_to?).with(:parsed_response).and_return(true)
        allow(error_response).to receive(:respond_to?).with(:headers).and_return(true)

        allow(described_class).to receive(:post).and_return(error_response)

        expect {
          critique_agent.critique(article)
        }.to raise_error(StandardError) do |error|
          expect(error.retryable?).to be true
          expect(error.error_code).to eq(429)
        end
      end
    end

    context 'when API returns status/code field' do
      it 'detects error from status field' do
        error_response = double("response",
          code: nil,
          parsed_response: { "status" => 429, "message" => "Quota exceeded" },
          headers: {},
          respond_to?: true
        )
        allow(error_response).to receive(:respond_to?).with(:code).and_return(false)
        allow(error_response).to receive(:respond_to?).with(:parsed_response).and_return(true)
        allow(error_response).to receive(:respond_to?).with(:headers).and_return(true)

        allow(described_class).to receive(:post).and_return(error_response)

        expect {
          critique_agent.critique(article)
        }.to raise_error(StandardError) do |error|
          expect(error.retryable?).to be true
          expect(error.error_code).to eq(429)
        end
      end
    end

    context 'when API returns plain text error' do
      it 'detects quota error from text body when http_status is nil' do
        # Test the string detection path when http_status is not available
        error_response = double("response")
        allow(error_response).to receive(:code).and_return(nil)
        allow(error_response).to receive(:parsed_response).and_return("Error: You exceeded your quota. Please retry in 43 seconds.")
        allow(error_response).to receive(:headers).and_return({})
        allow(error_response).to receive(:respond_to?).with(:code).and_return(false)
        allow(error_response).to receive(:respond_to?).with(:parsed_response).and_return(true)
        allow(error_response).to receive(:respond_to?).with(:headers).and_return(true)
        allow(error_response).to receive(:respond_to?).with(anything).and_return(false)

        allow(described_class).to receive(:post).and_return(error_response)

        expect {
          critique_agent.critique(article)
        }.to raise_error(StandardError) do |error|
          expect(error.respond_to?(:retryable?)).to be true
          expect(error.retryable?).to be true
        end
      end

      it 'detects quota error and marks as retryable when http_status is 429' do
        # Test that http_status 429 sets retryable correctly
        error_response = double("response")
        allow(error_response).to receive(:code).and_return(429)
        allow(error_response).to receive(:parsed_response).and_return("Error: You exceeded your quota.")
        allow(error_response).to receive(:headers).and_return({})
        allow(error_response).to receive(:respond_to?).with(:code).and_return(true)
        allow(error_response).to receive(:respond_to?).with(:parsed_response).and_return(true)
        allow(error_response).to receive(:respond_to?).with(:headers).and_return(true)
        allow(error_response).to receive(:respond_to?).with(anything).and_return(false)

        allow(described_class).to receive(:post).and_return(error_response)

        expect {
          critique_agent.critique(article)
        }.to raise_error(StandardError) do |error|
          expect(error.respond_to?(:retryable?)).to be true
          expect(error.retryable?).to be true
          expect(error.error_code).to eq(429)
          expect(error.error_type).to eq("quota")
        end
      end

      it '503 HTML body stores retryable: true, error_type: provider_5xx' do
        # Test HTML error response with 503 status
        error_response = double("response")
        allow(error_response).to receive(:code).and_return(503)
        allow(error_response).to receive(:parsed_response).and_return("<html><body>Service Unavailable</body></html>")
        allow(error_response).to receive(:headers).and_return({})
        allow(error_response).to receive(:respond_to?).with(:code).and_return(true)
        allow(error_response).to receive(:respond_to?).with(:parsed_response).and_return(true)
        allow(error_response).to receive(:respond_to?).with(:headers).and_return(true)
        allow(error_response).to receive(:respond_to?).with(anything).and_return(false)

        allow(described_class).to receive(:post).and_return(error_response)

        expect {
          critique_agent.critique(article)
        }.to raise_error(StandardError) do |error|
          expect(error.retryable?).to be true
          expect(error.error_code).to eq(503)
          expect(error.error_type).to eq("provider_5xx")
          expect(error.provider_error).to be_present
          expect(error.provider_error.length).to be <= 500
        end
      end

      it '401 stores retryable: false, error_type: auth' do
        error_response = double("response",
          code: 401,
          parsed_response: { "error" => { "code" => 401, "message" => "Unauthorized" } },
          headers: {},
          respond_to?: true
        )
        allow(error_response).to receive(:respond_to?).with(:code).and_return(true)
        allow(error_response).to receive(:respond_to?).with(:parsed_response).and_return(true)
        allow(error_response).to receive(:respond_to?).with(:headers).and_return(true)

        allow(described_class).to receive(:post).and_return(error_response)

        expect {
          critique_agent.critique(article)
        }.to raise_error(StandardError) do |error|
          expect(error.retryable?).to be false
          expect(error.error_code).to eq(401)
          expect(error.error_type).to eq("auth")
        end
      end

      it 'sanitizes provider_error: redacts API keys and Bearer tokens' do
        error_response = double("response",
          code: 429,
          parsed_response: {
            "error" => {
              "code" => 429,
              "message" => "Quota exceeded",
              "request_id" => "abc123",
              "debug_info" => "Bearer AIzaSyAbCdEfGhIjKlMnOpQrStUvWxYz1234567890"
            }
          },
          headers: {},
          respond_to?: true
        )
        allow(error_response).to receive(:respond_to?).with(:code).and_return(true)
        allow(error_response).to receive(:respond_to?).with(:parsed_response).and_return(true)
        allow(error_response).to receive(:respond_to?).with(:headers).and_return(true)

        allow(described_class).to receive(:post).and_return(error_response)

        expect {
          critique_agent.critique(article)
        }.to raise_error(StandardError) do |error|
          expect(error.provider_error).to be_present
          # Should redact Bearer tokens
          expect(error.provider_error).not_to include("AIzaSyAbCdEfGhIjKlMnOpQrStUvWxYz1234567890")
          expect(error.provider_error).to include("[REDACTED]")
          # Should preserve non-sensitive data
          expect(error.provider_error).to include("request_id")
        end
      end

      it 'normalizes response.code to Integer and handles edge cases' do
        # Test with string code (should be normalized)
        error_response = double("response",
          code: "429",  # String instead of Integer
          parsed_response: { "error" => { "code" => 429, "message" => "Quota exceeded" } },
          headers: {},
          respond_to?: true
        )
        allow(error_response).to receive(:respond_to?).with(:code).and_return(true)
        allow(error_response).to receive(:respond_to?).with(:parsed_response).and_return(true)
        allow(error_response).to receive(:respond_to?).with(:headers).and_return(true)

        allow(described_class).to receive(:post).and_return(error_response)

        expect {
          critique_agent.critique(article)
        }.to raise_error(StandardError) do |error|
          expect(error.error_code).to eq(429)
          expect(error.error_code).to be_a(Integer)
        end
      end

      it 'handles zero status code as nil' do
        # Test with zero status (should be treated as nil)
        error_response = double("response",
          code: 0,
          parsed_response: { "error" => { "code" => 500, "message" => "Server error" } },
          headers: {},
          respond_to?: true
        )
        allow(error_response).to receive(:respond_to?).with(:code).and_return(true)
        allow(error_response).to receive(:respond_to?).with(:parsed_response).and_return(true)
        allow(error_response).to receive(:respond_to?).with(:headers).and_return(true)

        allow(described_class).to receive(:post).and_return(error_response)

        expect {
          critique_agent.critique(article)
        }.to raise_error(StandardError) do |error|
          # Should use JSON error code (500) since HTTP status was 0 (invalid)
          expect(error.error_code).to eq(500)
        end
      end
    end
  end
end
