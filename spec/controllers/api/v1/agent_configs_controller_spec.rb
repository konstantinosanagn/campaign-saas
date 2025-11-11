require 'rails_helper'

RSpec.describe Api::V1::AgentConfigsController, type: :controller do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:campaign) { create(:campaign, user: user) }
  let(:other_campaign) { create(:campaign, user: other_user) }

  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:authenticate_user!).and_return(true)
  end

  describe 'GET #index' do
    it 'returns agent configs for campaign belonging to current user' do
      config = create(:agent_config, campaign: campaign, agent_name: 'WRITER')

      get :index, params: { campaign_id: campaign.id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['campaignId']).to eq(campaign.id)
      expect(json['configs']).to be_an(Array)
      expect(json['configs'].first['agentName']).to eq('WRITER')
    end

    it 'returns 404 when campaign not found or unauthorized' do
      get :index, params: { campaign_id: other_campaign.id }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['errors']).to include('Campaign not found or unauthorized')
    end
  end

  describe 'GET #show' do
    it 'returns the agent config' do
      config = create(:agent_config, campaign: campaign, agent_name: 'SEARCH')

      get :show, params: { campaign_id: campaign.id, id: config.id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['agentName']).to eq('SEARCH')
      expect(json['id']).to eq(config.id)
    end

    it 'returns 404 when config not found' do
      get :show, params: { campaign_id: campaign.id, id: 123 }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['errors']).to include('Agent config not found')
    end
  end

  describe 'POST #create' do
    it 'creates a new agent config with valid params' do
      post :create, params: { campaign_id: campaign.id, agent_config: { agentName: 'CRITIQUE', enabled: true, settings: { strictness: 'moderate' } } }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['agentName']).to eq('CRITIQUE')
      expect(json['enabled']).to be true
      expect(json['settings']['strictness']).to eq('moderate')
    end

    it 'returns 422 for invalid agent name' do
      post :create, params: { campaign_id: campaign.id, agent_config: { agentName: 'INVALID' } }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors'].first).to match(/Invalid agent name/)
    end

    it 'returns 422 when config already exists' do
      create(:agent_config, campaign: campaign, agent_name: 'DESIGN')

      post :create, params: { campaign_id: campaign.id, agent_config: { agentName: 'DESIGN' } }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors']).to include('Agent config already exists for this campaign')
    end

    it 'returns 404 when campaign not found' do
      post :create, params: { campaign_id: other_campaign.id, agent_config: { agentName: 'SEARCH' } }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['errors']).to include('Campaign not found or unauthorized')
    end

    it 'renders errors when save fails' do
      allow_any_instance_of(AgentConfig).to receive(:save).and_return(false)
      allow_any_instance_of(AgentConfig).to receive_message_chain(:errors, :full_messages).and_return(['save failed'])

      post :create, params: { campaign_id: campaign.id, agent_config: { agentName: 'SEARCH' } }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors']).to include('save failed')
    end

    it 'defaults settings to empty hash when settings missing' do
      post :create, params: { campaign_id: campaign.id, agent_config: { agentName: 'SEARCH' } }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['settings']).to eq({})
    end
  end

  describe 'PATCH #update' do
    it 'updates enabled and settings' do
      config = create(:agent_config, campaign: campaign, agent_name: 'WRITER', enabled: true, settings: { 'tone' => 'professional' })

      patch :update, params: { campaign_id: campaign.id, id: config.id, agent_config: { enabled: false, settings: { tone: 'friendly' } } }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['enabled']).to be false
      expect(json['settings']['tone']).to eq('friendly')
    end

    it 'accepts top-level enabled param via fallback agent_config_params' do
      config = create(:agent_config, campaign: campaign, agent_name: 'WRITER', enabled: true)

      patch :update, params: { campaign_id: campaign.id, id: config.id, enabled: false }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['enabled']).to be false
    end

    it 'returns 404 when campaign not found' do
      config = create(:agent_config, campaign: campaign, agent_name: 'WRITER')

      patch :update, params: { campaign_id: other_campaign.id, id: config.id, agent_config: { enabled: false } }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['errors']).to include('Campaign not found or unauthorized')
    end

    it 'renders errors when update fails' do
      config = create(:agent_config, campaign: campaign, agent_name: 'WRITER')
      allow_any_instance_of(AgentConfig).to receive(:update).and_return(false)
      allow_any_instance_of(AgentConfig).to receive_message_chain(:errors, :full_messages).and_return(['update failed'])

      patch :update, params: { campaign_id: campaign.id, id: config.id, agent_config: { enabled: false } }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors']).to include('update failed')
    end

    it 'returns 404 when config not found' do
      patch :update, params: { campaign_id: campaign.id, id: 123, agent_config: { enabled: false } }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['errors']).to include('Agent config not found')
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the config' do
      config = create(:agent_config, campaign: campaign, agent_name: 'SEARCH')

      expect {
        delete :destroy, params: { campaign_id: campaign.id, id: config.id }
      }.to change(AgentConfig, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it 'returns 404 when config not found' do
      delete :destroy, params: { campaign_id: campaign.id, id: 123 }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['errors']).to include('Agent config not found')
    end

    it 'returns 404 when campaign not found' do
      config = create(:agent_config, campaign: campaign, agent_name: 'SEARCH')

      delete :destroy, params: { campaign_id: other_campaign.id, id: config.id }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['errors']).to include('Campaign not found or unauthorized')
    end
  end
end
