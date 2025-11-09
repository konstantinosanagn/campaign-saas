require 'rails_helper'

RSpec.describe Api::V1::ApiKeysController, type: :request do
  let(:user) { create(:user) }

  describe 'GET #show' do
    context 'when authenticated' do
      before { sign_in user }

      it 'returns empty keys when session has no keys' do
        get '/api/v1/api_keys', headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['llmApiKey']).to eq('')
        expect(json_response['tavilyApiKey']).to eq('')
      end

      it 'returns stored keys from session' do
        # Set session keys directly (simulating previous update)
        get '/api/v1/api_keys', headers: { 'Accept' => 'application/json' }

        # Update keys first
        put '/api/v1/api_keys', params: {
          llmApiKey: 'test-llm-key',
          tavilyApiKey: 'test-tavily-key'
        }, headers: { 'Accept' => 'application/json' }

        # Then retrieve them
        get '/api/v1/api_keys', headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['llmApiKey']).to eq('test-llm-key')
        expect(json_response['tavilyApiKey']).to eq('test-tavily-key')
      end
    end

    context 'when not authenticated' do
      it 'returns 401 unauthorized' do
        get '/api/v1/api_keys', headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT #update' do
    context 'when authenticated' do
      before { sign_in user }

      context 'with direct parameters' do
        it 'stores llmApiKey in session' do
          put '/api/v1/api_keys', params: {
            llmApiKey: 'new-llm-key',
            tavilyApiKey: 'new-tavily-key'
          }, headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:success)
          json_response = JSON.parse(response.body)
          expect(json_response['llmApiKey']).to eq('new-llm-key')
          expect(json_response['tavilyApiKey']).to eq('new-tavily-key')
        end

        it 'updates only llmApiKey when tavilyApiKey is not provided' do
          put '/api/v1/api_keys', params: {
            llmApiKey: 'only-llm-key'
          }, headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:success)
          json_response = JSON.parse(response.body)
          expect(json_response['llmApiKey']).to eq('only-llm-key')
          expect(json_response['tavilyApiKey']).to be_nil
        end

        it 'updates only tavilyApiKey when llmApiKey is not provided' do
          put '/api/v1/api_keys', params: {
            tavilyApiKey: 'only-tavily-key'
          }, headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:success)
          json_response = JSON.parse(response.body)
          expect(json_response['tavilyApiKey']).to eq('only-tavily-key')
          expect(json_response['llmApiKey']).to be_nil
        end
      end

      context 'with nested parameters' do
        it 'accepts nested api_keys hash' do
          put '/api/v1/api_keys', params: {
            api_keys: {
              llmApiKey: 'nested-llm-key',
              tavilyApiKey: 'nested-tavily-key'
            }
          }, headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:success)
          json_response = JSON.parse(response.body)
          expect(json_response['llmApiKey']).to eq('nested-llm-key')
          expect(json_response['tavilyApiKey']).to eq('nested-tavily-key')
        end

        it 'prefers direct parameters over nested when both are provided' do
          put '/api/v1/api_keys', params: {
            llmApiKey: 'direct-key',
            api_keys: {
              llmApiKey: 'nested-key'
            }
          }, headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:success)
          json_response = JSON.parse(response.body)
          expect(json_response['llmApiKey']).to eq('direct-key')
        end
      end

      it 'persists keys across requests' do
        # Set keys
        put '/api/v1/api_keys', params: {
          llmApiKey: 'persistent-llm',
          tavilyApiKey: 'persistent-tavily'
        }, headers: { 'Accept' => 'application/json' }

        # Retrieve them
        get '/api/v1/api_keys', headers: { 'Accept' => 'application/json' }

        json_response = JSON.parse(response.body)
        expect(json_response['llmApiKey']).to eq('persistent-llm')
        expect(json_response['tavilyApiKey']).to eq('persistent-tavily')
      end

      it 'allows clearing keys by setting them to empty string' do
        # Set keys first
        put '/api/v1/api_keys', params: {
          llmApiKey: 'test-key',
          tavilyApiKey: 'test-key'
        }, headers: { 'Accept' => 'application/json' }

        # Clear them
        put '/api/v1/api_keys', params: {
          llmApiKey: '',
          tavilyApiKey: ''
        }, headers: { 'Accept' => 'application/json' }

        get '/api/v1/api_keys', headers: { 'Accept' => 'application/json' }
        json_response = JSON.parse(response.body)
        expect(json_response['llmApiKey']).to eq('')
        expect(json_response['tavilyApiKey']).to eq('')
      end
    end

    context 'when not authenticated' do
      it 'returns 401 unauthorized' do
        put '/api/v1/api_keys', params: {
          llmApiKey: 'test-key'
        }, headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
