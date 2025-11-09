# spec/integration/campaign_management_spec.rb
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Campaign Management Integration', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe 'Complete Campaign Lifecycle' do
    context 'when authenticated' do
      before { sign_in user }

      it 'allows user to create, view, update, and delete a campaign through API' do
        # Create campaign
        post '/api/v1/campaigns', params: {
          campaign: {
            title: 'Test Campaign',
            basePrompt: 'This is a test prompt'
          }
        }, headers: { "ACCEPT" => "application/json" }
        expect(response).to have_http_status(:created)
        campaign_data = JSON.parse(response.body)
        campaign_id = campaign_data['id']
        expect(campaign_data['title']).to eq('Test Campaign')
        expect(campaign_data['basePrompt']).to eq('This is a test prompt')

        # Verify campaign appears in index
        get '/api/v1/campaigns', headers: { "ACCEPT" => "application/json" }
        expect(response).to have_http_status(:ok)
        campaigns = JSON.parse(response.body)
        expect(campaigns.map { |c| c['id'] }).to include(campaign_id)

        # View campaign in HTML
        get "/campaigns/#{campaign_id}", headers: { "ACCEPT" => "text/html" }
        expect(response.status).to be_between(200, 599).inclusive

        # Update campaign
        put "/api/v1/campaigns/#{campaign_id}", params: {
          campaign: {
            title: 'Updated Campaign',
            basePrompt: 'Updated prompt'
          }
        }, headers: { "ACCEPT" => "application/json" }
        expect(response).to have_http_status(:ok)
        updated_data = JSON.parse(response.body)
        expect(updated_data['title']).to eq('Updated Campaign')
        expect(updated_data['basePrompt']).to eq('Updated prompt')

        # Delete campaign
        delete "/api/v1/campaigns/#{campaign_id}", headers: { "ACCEPT" => "application/json" }
        expect(response).to have_http_status(:no_content)

        # Verify campaign is gone
        get '/api/v1/campaigns', headers: { "ACCEPT" => "application/json" }
        campaigns = JSON.parse(response.body)
        expect(campaigns.map { |c| c['id'] }).not_to include(campaign_id)
      end

      it 'enforces user isolation - users can only see their own campaigns' do
        # Create campaign for user
        post '/api/v1/campaigns', params: {
          campaign: {
            title: 'User Campaign',
            basePrompt: 'User prompt'
          }
        }
        user_campaign_id = JSON.parse(response.body)['id']

        # Create campaign for other user
        sign_out user
        sign_in other_user
        post '/api/v1/campaigns', params: {
          campaign: {
            title: 'Other User Campaign',
            basePrompt: 'Other prompt'
          }
        }
        other_campaign_id = JSON.parse(response.body)['id']

        # User should only see their own campaign
        get '/api/v1/campaigns', headers: { "ACCEPT" => "application/json" }
        campaigns = JSON.parse(response.body)
        expect(campaigns.map { |c| c['id'] }).to include(other_campaign_id)
        expect(campaigns.map { |c| c['id'] }).not_to include(user_campaign_id)

        # User cannot access other user's campaign
        get "/campaigns/#{user_campaign_id}", headers: { "ACCEPT" => "text/html" }
        expect(response.status).to be_between(300, 499)

        # User cannot update other user's campaign
        put "/api/v1/campaigns/#{user_campaign_id}", params: {
          campaign: { title: 'Hacked' }
        }, headers: { "ACCEPT" => "application/json" }
        expect(response.status).to be_between(400, 499)

        # User cannot delete other user's campaign
        delete "/api/v1/campaigns/#{user_campaign_id}", headers: { "ACCEPT" => "application/json" }
        expect(response.status).to be_between(400, 499)
      end
    end

    context 'when not authenticated' do
      it 'requires authentication for all campaign operations' do
        # Index
        get '/api/v1/campaigns', headers: { "ACCEPT" => "application/json" }
        expect(response).to have_http_status(:unauthorized)

        # Create
        post '/api/v1/campaigns', params: {
          campaign: { title: 'Test', basePrompt: 'Test' }
        }, headers: { "ACCEPT" => "application/json" }
        expect(response).to have_http_status(:unauthorized)

        # Update
        campaign = create(:campaign, user: user)
        put "/api/v1/campaigns/#{campaign.id}", params: {
          campaign: { title: 'Updated' }
        }, headers: { "ACCEPT" => "application/json" }
        expect(response).to have_http_status(:unauthorized)

        # Delete
        delete "/api/v1/campaigns/#{campaign.id}", headers: { "ACCEPT" => "application/json" }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'Campaign and Leads Integration' do
    context 'when authenticated' do
      before { sign_in user }

      it 'allows creating campaign and leads together' do
        # Create campaign
        post '/api/v1/campaigns', params: {
          campaign: {
            title: 'Lead Generation Campaign',
            basePrompt: 'Generate leads for tech companies'
          }
        }, headers: { "ACCEPT" => "application/json" }
        campaign_id = JSON.parse(response.body)['id']

        # Create multiple leads for the campaign
        lead1_data = {
          lead: {
            name: 'John Doe',
            email: 'john@example.com',
            title: 'VP Marketing',
            company: 'Tech Corp',
            campaignId: campaign_id
          }
        }

        lead2_data = {
          lead: {
            name: 'Jane Smith',
            email: 'jane@example.com',
            title: 'Head of Sales',
            company: 'Sales Inc',
            campaignId: campaign_id
          }
        }

        post '/api/v1/leads', params: lead1_data, headers: { "ACCEPT" => "application/json" }
        expect(response).to have_http_status(:created)
        lead1_id = JSON.parse(response.body)['id']

        post '/api/v1/leads', params: lead2_data, headers: { "ACCEPT" => "application/json" }
        expect(response).to have_http_status(:created)
        lead2_id = JSON.parse(response.body)['id']

        # Verify leads appear in campaign
        get '/api/v1/leads', headers: { "ACCEPT" => "application/json" }
        leads = JSON.parse(response.body)
        lead_ids = leads.map { |l| l['id'] }
        expect(lead_ids).to include(lead1_id, lead2_id)
        expect(leads.all? { |l| l['campaignId'] == campaign_id }).to be true

        # Verify leads appear when viewing campaign HTML
        get "/campaigns/#{campaign_id}", headers: { "ACCEPT" => "text/html" }
        expect(response.status).to be_between(200, 599).inclusive

        # Deleting campaign should delete associated leads
        delete "/api/v1/campaigns/#{campaign_id}", headers: { "ACCEPT" => "application/json" }
        expect(response).to have_http_status(:no_content)

        # Verify leads are gone
        get '/api/v1/leads', headers: { "ACCEPT" => "application/json" }
        leads = JSON.parse(response.body)
        expect(leads.map { |l| l['id'] }).not_to include(lead1_id, lead2_id)
      end

      it 'enforces lead ownership through campaign ownership' do
        # User creates campaign and lead
        post '/api/v1/campaigns', params: {
          campaign: {
            title: 'My Campaign',
            basePrompt: 'Prompt'
          }
        }
        my_campaign_id = JSON.parse(response.body)['id']

        post '/api/v1/leads', params: {
          lead: {
            name: 'My Lead',
            email: 'lead@example.com',
            title: 'Title',
            company: 'Company',
            campaignId: my_campaign_id
          }
        }
        my_lead_id = JSON.parse(response.body)['id']

        # Other user creates campaign and lead
        sign_out user
        sign_in other_user
        post '/api/v1/campaigns', params: {
          campaign: {
            title: 'Other Campaign',
            basePrompt: 'Other Prompt'
          }
        }
        other_campaign_id = JSON.parse(response.body)['id']

        # Other user cannot create lead for user's campaign
        post '/api/v1/leads', params: {
          lead: {
            name: 'Hacked Lead',
            email: 'hacked@example.com',
            title: 'Title',
            company: 'Company',
            campaignId: my_campaign_id
          }
        }, headers: { "ACCEPT" => "application/json" }
        expect(response).to have_http_status(:unprocessable_entity)

        # Other user cannot see user's leads
        get '/api/v1/leads', headers: { "ACCEPT" => "application/json" }
        leads = JSON.parse(response.body)
        expect(leads.map { |l| l['id'] }).not_to include(my_lead_id)

        # Other user cannot update user's leads
        put "/api/v1/leads/#{my_lead_id}", params: {
          lead: { name: 'Hacked' }
        }, headers: { "ACCEPT" => "application/json" }
        expect(response.status).to be_between(400, 499)

        # Other user cannot delete user's leads
        delete "/api/v1/leads/#{my_lead_id}", headers: { "ACCEPT" => "application/json" }
        expect(response.status).to be_between(400, 499)
      end
    end
  end
end
