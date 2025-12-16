require 'rails_helper'

RSpec.describe Api::V1::AgentConfigsController, type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:campaign) { create(:campaign, user: user) }
  let(:other_campaign) { create(:campaign, user: other_user) }
  let(:valid_attributes) do
    {
      agent_config: {
        agent_name: 'WRITER',
        enabled: true,
        settings: { product_info: 'Test product', sender_company: 'Test Company' }
      }
    }
  end

  describe 'GET #index' do
    context 'when authenticated' do
      before { sign_in user }

      it 'returns all agent configs for the campaign' do
        config1 = create(:agent_config, campaign: campaign, agent_name: 'SEARCH')
        config2 = create(:agent_config, campaign: campaign, agent_name: 'WRITER')
        create(:agent_config, campaign: other_campaign, agent_name: 'SEARCH') # Should not be included

        get "/api/v1/campaigns/#{campaign.id}/agent_configs", headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['campaignId']).to eq(campaign.id)
        expect(json_response['configs'].length).to eq(2)
        expect(json_response['configs'].map { |c| c['id'] }).to contain_exactly(config1.id, config2.id)
      end

      it 'returns empty array when campaign has no configs' do
        get "/api/v1/campaigns/#{campaign.id}/agent_configs", headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['configs']).to eq([])
      end

      context 'when campaign belongs to another user' do
        it 'returns 404 not found' do
          get "/api/v1/campaigns/#{other_campaign.id}/agent_configs", headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:not_found)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to include('Campaign not found or unauthorized')
        end
      end
    end

    context 'when not authenticated' do
      it 'returns 401 unauthorized' do
        get "/api/v1/campaigns/#{campaign.id}/agent_configs", headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET #show' do
    let!(:config) { create(:agent_config, campaign: campaign, agent_name: 'WRITER') }

    context 'when authenticated' do
      before { sign_in user }

      it 'returns the agent config' do
        get "/api/v1/campaigns/#{campaign.id}/agent_configs/#{config.id}", headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['id']).to eq(config.id)
        expect(json_response['agentName']).to eq('WRITER')
      end

      context 'when config belongs to another user\'s campaign' do
        let!(:other_config) { create(:agent_config, campaign: other_campaign) }

        it 'returns 404 not found' do
          get "/api/v1/campaigns/#{other_campaign.id}/agent_configs/#{other_config.id}", headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:not_found)
        end
      end

      context 'when config does not exist' do
        it 'returns 404 not found' do
          get "/api/v1/campaigns/#{campaign.id}/agent_configs/99999", headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'when not authenticated' do
      it 'returns 401 unauthorized' do
        get "/api/v1/campaigns/#{campaign.id}/agent_configs/#{config.id}", headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST #create' do
    context 'when authenticated' do
      before { sign_in user }

      context 'with valid attributes' do
        it 'creates a new agent config' do
          expect {
            post "/api/v1/campaigns/#{campaign.id}/agent_configs", params: valid_attributes, headers: { 'Accept' => 'application/json' }
          }.to change(AgentConfig, :count).by(1)
        end

        it 'associates config with campaign' do
          post "/api/v1/campaigns/#{campaign.id}/agent_configs", params: valid_attributes, headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:created)
          config = AgentConfig.last
          expect(config.campaign).to eq(campaign)
        end

        it 'returns the created config' do
          post "/api/v1/campaigns/#{campaign.id}/agent_configs", params: valid_attributes, headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:created)
          json_response = JSON.parse(response.body)
          expect(json_response['agentName']).to eq('WRITER')
          expect(json_response['enabled']).to be true
        end
      end

      context 'with invalid agent name' do
        it 'returns 422 with error message' do
          invalid_attributes = valid_attributes.dup
          invalid_attributes[:agent_config][:agent_name] = 'INVALID'

          post "/api/v1/campaigns/#{campaign.id}/agent_configs", params: invalid_attributes, headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:unprocessable_entity)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to be_present
        end
      end

      context 'when agent config already exists' do
        let!(:existing_config) { create(:agent_config, campaign: campaign, agent_name: 'WRITER', enabled: false) }

        it 'returns 200 and updates the existing config' do
          post "/api/v1/campaigns/#{campaign.id}/agent_configs", params: valid_attributes, headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:ok)
          json_response = JSON.parse(response.body)
          expect(json_response['agentName']).to eq('WRITER')
          expect(json_response['enabled']).to be true
        end
      end

      context 'when campaign belongs to another user' do
        it 'returns 404 not found' do
          post "/api/v1/campaigns/#{other_campaign.id}/agent_configs", params: valid_attributes, headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'when not authenticated' do
      it 'returns 401 unauthorized' do
        post "/api/v1/campaigns/#{campaign.id}/agent_configs", params: valid_attributes, headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH #update' do
    let!(:config) { create(:agent_config, campaign: campaign, agent_name: 'WRITER', enabled: true) }
    let(:update_attributes) do
      {
        agent_config: {
          enabled: false,
          settings: { product_info: 'Updated product info' }
        }
      }
    end

    context 'when authenticated' do
      before { sign_in user }

      context 'with valid attributes' do
        it 'updates the config' do
          patch "/api/v1/campaigns/#{campaign.id}/agent_configs/#{config.id}", params: update_attributes, headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:ok)
          config.reload
          expect(config.enabled).to be false
        end

        it 'returns the updated config' do
          patch "/api/v1/campaigns/#{campaign.id}/agent_configs/#{config.id}", params: update_attributes, headers: { 'Accept' => 'application/json' }

          json_response = JSON.parse(response.body)
          expect(json_response['enabled']).to be false
        end
      end

      context 'when config belongs to another user\'s campaign' do
        let!(:other_config) { create(:agent_config, campaign: other_campaign) }

        it 'returns 404 not found' do
          patch "/api/v1/campaigns/#{other_campaign.id}/agent_configs/#{other_config.id}", params: update_attributes, headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:not_found)
        end
      end

      context 'when config does not exist' do
        it 'returns 404 not found' do
          patch "/api/v1/campaigns/#{campaign.id}/agent_configs/99999", params: update_attributes, headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'when not authenticated' do
      it 'returns 401 unauthorized' do
        patch "/api/v1/campaigns/#{campaign.id}/agent_configs/#{config.id}", params: update_attributes, headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:config) { create(:agent_config, campaign: campaign, agent_name: 'WRITER') }

    context 'when authenticated' do
      before { sign_in user }

      it 'destroys the config' do
        expect {
          delete "/api/v1/campaigns/#{campaign.id}/agent_configs/#{config.id}", headers: { 'Accept' => 'application/json' }
        }.to change(AgentConfig, :count).by(-1)
      end

      it 'returns 204 no content' do
        delete "/api/v1/campaigns/#{campaign.id}/agent_configs/#{config.id}", headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:no_content)
      end

      context 'when config belongs to another user\'s campaign' do
        let!(:other_config) { create(:agent_config, campaign: other_campaign) }

        it 'returns 404 not found' do
          delete "/api/v1/campaigns/#{other_campaign.id}/agent_configs/#{other_config.id}", headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:not_found)
          expect(AgentConfig.find_by(id: other_config.id)).to be_present
        end
      end

      context 'when config does not exist' do
        it 'returns 404' do
          delete "/api/v1/campaigns/#{campaign.id}/agent_configs/99999", headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'when not authenticated' do
      it 'returns 401 unauthorized' do
        delete "/api/v1/campaigns/#{campaign.id}/agent_configs/#{config.id}", headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
