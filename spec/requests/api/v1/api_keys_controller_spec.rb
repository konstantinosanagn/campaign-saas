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
        user.update!(llm_api_key: 'test-llm-key', tavily_api_key: 'test-tavily-key')

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

      it 'stores llmApiKey and tavilyApiKey' do
        put '/api/v1/api_keys', params: {
          api_key: {
            llmApiKey: 'new-llm-key',
            tavilyApiKey: 'new-tavily-key'
          }
        }, headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        user.reload
        expect(json_response['llmApiKey']).to eq('new-llm-key')
        expect(json_response['tavilyApiKey']).to eq('new-tavily-key')
        expect(user.llm_api_key).to eq('new-llm-key')
        expect(user.tavily_api_key).to eq('new-tavily-key')
      end

      it 'updates only llmApiKey when tavilyApiKey is not provided' do
        user.update!(llm_api_key: 'existing-llm', tavily_api_key: 'existing-tavily')

        put '/api/v1/api_keys', params: {
          api_key: { llmApiKey: 'only-llm-key' }
        }, headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['llmApiKey']).to eq('only-llm-key')
        expect(json_response['tavilyApiKey']).to eq('existing-tavily')
        expect(user.reload.llm_api_key).to eq('only-llm-key')
        expect(user.tavily_api_key).to eq('existing-tavily')
      end

      it 'updates only tavilyApiKey when llmApiKey is not provided' do
        user.update!(llm_api_key: 'existing-llm', tavily_api_key: 'existing-tavily')

        put '/api/v1/api_keys', params: {
          api_key: { tavilyApiKey: 'only-tavily-key' }
        }, headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['tavilyApiKey']).to eq('only-tavily-key')
        expect(json_response['llmApiKey']).to eq('existing-llm')
        expect(user.reload.tavily_api_key).to eq('only-tavily-key')
        expect(user.llm_api_key).to eq('existing-llm')
      end

      it 'persists keys across requests' do
        # Set keys
        put '/api/v1/api_keys', params: {
          api_key: {
            llmApiKey: 'persistent-llm',
            tavilyApiKey: 'persistent-tavily'
          }
        }, headers: { 'Accept' => 'application/json' }

        # Retrieve them
        get '/api/v1/api_keys', headers: { 'Accept' => 'application/json' }

        json_response = JSON.parse(response.body)
        expect(json_response['llmApiKey']).to eq('persistent-llm')
        expect(json_response['tavilyApiKey']).to eq('persistent-tavily')
        expect(user.reload.llm_api_key).to eq('persistent-llm')
        expect(user.tavily_api_key).to eq('persistent-tavily')
      end

      it 'allows clearing keys by setting them to empty string' do
        # Set keys first
        put '/api/v1/api_keys', params: {
          api_key: {
            llmApiKey: 'test-key',
            tavilyApiKey: 'test-key'
          }
        }, headers: { 'Accept' => 'application/json' }

        # Clear them
        put '/api/v1/api_keys', params: {
          api_key: {
            llmApiKey: '',
            tavilyApiKey: ''
          }
        }, headers: { 'Accept' => 'application/json' }

        get '/api/v1/api_keys', headers: { 'Accept' => 'application/json' }
        json_response = JSON.parse(response.body)
        expect(json_response['llmApiKey']).to eq('')
        expect(json_response['tavilyApiKey']).to eq('')
        expect(user.reload.llm_api_key).to eq('')
        expect(user.tavily_api_key).to eq('')
      end
    end

    context 'when not authenticated' do
      it 'returns 401 unauthorized' do
        put '/api/v1/api_keys', params: {
          api_key: { llmApiKey: 'test-key' }
        }, headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
