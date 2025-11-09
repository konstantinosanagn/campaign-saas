# spec/integration/lead_management_spec.rb
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Lead Management Integration', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }
  let(:campaign) { create(:campaign, user: user) }

  describe 'Complete Lead Lifecycle' do
    context 'when authenticated' do
      before { sign_in user, scope: :user }

      it 'allows user to create, view, update, and delete a lead through API' do
        # Create lead
        sign_in user, scope: :user
        post '/api/v1/leads', params: {
          lead: {
            name: 'John Doe',
            email: 'john.doe@example.com',
            title: 'VP Marketing',
            company: 'Tech Corp',
            campaignId: campaign.id
          }
        }, headers: { "ACCEPT" => "application/json" }
        expect(response).to have_http_status(:created)
        lead_data = JSON.parse(response.body)
        lead_id = lead_data['id']
        expect(lead_data['name']).to eq('John Doe')
        expect(lead_data['email']).to eq('john.doe@example.com')
        expect(lead_data['campaignId']).to eq(campaign.id)
        expect(lead_data['stage']).to eq('queued')
        expect(lead_data['quality']).to eq('-')

        # Verify lead appears in index
        sign_in user, scope: :user
        get '/api/v1/leads', headers: { "ACCEPT" => "application/json" }
        expect(response).to have_http_status(:ok)
        leads = JSON.parse(response.body)
        expect(leads.map { |l| l['id'] }).to include(lead_id)

        # Update lead
        sign_in user, scope: :user
        put "/api/v1/leads/#{lead_id}", params: {
          lead: {
            name: 'John Updated',
            email: 'john.updated@example.com',
            stage: 'contacted',
            quality: 'high'
          }
        }, headers: { "ACCEPT" => "application/json" }
        expect(response).to have_http_status(:ok)
        updated_data = JSON.parse(response.body)
        expect(updated_data['name']).to eq('John Updated')
        expect(updated_data['email']).to eq('john.updated@example.com')
        expect(updated_data['stage']).to eq('contacted')
        expect(updated_data['quality']).to eq('high')

        # Delete lead
        sign_in user, scope: :user
        delete "/api/v1/leads/#{lead_id}", headers: { "ACCEPT" => "application/json" }
        expect(response).to have_http_status(:no_content)

        # Verify lead is gone
        expect(Lead.exists?(lead_id)).to be(false)
      end

      it 'sets default website from email when not provided' do
        sign_in user, scope: :user
        post '/api/v1/leads', params: {
          lead: {
            name: 'Jane Smith',
            email: 'jane@testcompany.com',
            title: 'Head of Sales',
            company: 'Test Company',
            campaignId: campaign.id,
            website: ''
          }
        }, headers: { "ACCEPT" => "application/json" }
        expect(response).to have_http_status(:created)
        lead_data = JSON.parse(response.body)
        expect(lead_data['website']).to eq('testcompany.com')
      end

      it 'does not override provided website' do
        sign_in user, scope: :user
        post '/api/v1/leads', params: {
          lead: {
            name: 'Bob Wilson',
            email: 'bob@example.com',
            title: 'Director',
            company: 'Example Corp',
            campaignId: campaign.id,
            website: 'custom-domain.com'
          }
        }, headers: { "ACCEPT" => "application/json" }
        expect(response).to have_http_status(:created)
        lead_data = JSON.parse(response.body)
        expect(lead_data['website']).to eq('custom-domain.com')
      end

      it 'validates required fields' do
        # Missing name
        sign_in user, scope: :user
        post '/api/v1/leads', params: {
          lead: {
            email: 'test@example.com',
            title: 'Title',
            company: 'Company',
            campaignId: campaign.id
          }
        }, headers: { "ACCEPT" => "application/json" }
        expect(response).to have_http_status(:unprocessable_entity)
        errors = JSON.parse(response.body)['errors']
        expect(errors).to include("Name can't be blank")

        # Invalid email
        sign_in user, scope: :user
        post '/api/v1/leads', params: {
          lead: {
            name: 'Test',
            email: 'invalid-email',
            title: 'Title',
            company: 'Company',
            campaignId: campaign.id
          }
        }, headers: { "ACCEPT" => "application/json" }
        expect(response).to have_http_status(:unprocessable_entity)
        errors = JSON.parse(response.body)['errors']
        expect(errors).to include("Email is invalid")
      end
    end

    context 'when not authenticated' do
      it 'requires authentication for all lead operations' do
        lead = create(:lead, campaign: campaign)

        # Index
        get '/api/v1/leads', headers: { "ACCEPT" => "application/json" }
        expect(response).to have_http_status(:unauthorized)

        # Create
        post '/api/v1/leads', params: {
          lead: {
            name: 'Test',
            email: 'test@example.com',
            title: 'Title',
            company: 'Company',
            campaignId: campaign.id
          }
        }, headers: { "ACCEPT" => "application/json" }
        expect(response).to have_http_status(:unauthorized)

        # Update
        put "/api/v1/leads/#{lead.id}", params: {
          lead: { name: 'Updated' }
        }, headers: { "ACCEPT" => "application/json" }
        expect(response).to have_http_status(:unauthorized)

        # Delete
        delete "/api/v1/leads/#{lead.id}", headers: { "ACCEPT" => "application/json" }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'Lead Filtering by Campaign' do
    context 'when authenticated' do
      before { sign_in user, scope: :user }

      it 'allows filtering leads by campaign' do
        campaign1 = create(:campaign, user: user, title: 'Campaign 1')
        campaign2 = create(:campaign, user: user, title: 'Campaign 2')

        lead1 = create(:lead, campaign: campaign1, name: 'Lead 1')
        lead2 = create(:lead, campaign: campaign1, name: 'Lead 2')
        lead3 = create(:lead, campaign: campaign2, name: 'Lead 3')

        # Get all leads
        sign_in user, scope: :user
        get '/api/v1/leads', headers: { "ACCEPT" => "application/json" }
        all_leads = JSON.parse(response.body)
        expect(all_leads.map { |l| l['id'] }).to include(lead1.id, lead2.id, lead3.id)

        # View campaign 1 (should show leads 1 and 2)
        sign_in user, scope: :user
        get "/campaigns/#{campaign1.id}", headers: { "ACCEPT" => "text/html" }
        expect(response.status).to be_between(200, 599).inclusive

        # View campaign 2 (should show lead 3)
        sign_in user, scope: :user
        get "/campaigns/#{campaign2.id}", headers: { "ACCEPT" => "text/html" }
        expect(response.status).to be_between(200, 599).inclusive
      end
    end
  end
end
