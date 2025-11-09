# spec/integration/error_handling_spec.rb
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Error Handling Integration', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe 'Invalid Resource Access' do
    context 'when authenticated' do
      before { sign_in user, scope: :user }

      it 'handles accessing non-existent campaign gracefully' do
        get '/campaigns/999999', headers: { "ACCEPT" => "text/html" }
        expect(response.status).to be_between(300, 499)

        put '/api/v1/campaigns/999999', params: {
          campaign: { title: 'Updated' }
        }, headers: { "ACCEPT" => "application/json" }
        expect(response.status).to be_between(400, 499)

        delete '/api/v1/campaigns/999999', headers: { "ACCEPT" => "application/json" }
        expect(response.status).to be_between(400, 499)
      end

      it 'handles accessing non-existent lead gracefully' do
        get '/api/v1/leads/999999', headers: { "ACCEPT" => "application/json" }
        expect(response.status).to be_between(400, 499)

        put '/api/v1/leads/999999', params: {
          lead: { name: 'Updated' }
        }, headers: { "ACCEPT" => "application/json" }
        expect(response.status).to be_between(400, 499)

        delete '/api/v1/leads/999999', headers: { "ACCEPT" => "application/json" }
        expect(response.status).to be_between(400, 499)
      end

      it 'handles accessing other user\'s resources gracefully' do
        other_campaign = create(:campaign, user: other_user)
        other_lead = create(:lead, campaign: other_campaign)

        # Cannot access other user's campaign
        get "/campaigns/#{other_campaign.id}", headers: { "ACCEPT" => "text/html" }
        expect(response.status).to be_between(300, 499)

        put "/api/v1/campaigns/#{other_campaign.id}", params: {
          campaign: { title: 'Hacked' }
        }, headers: { "ACCEPT" => "application/json" }
        expect(response.status).to be_between(400, 499)

        delete "/api/v1/campaigns/#{other_campaign.id}", headers: { "ACCEPT" => "application/json" }
        expect(response.status).to be_between(400, 499)

        # Cannot access other user's lead
        put "/api/v1/leads/#{other_lead.id}", params: {
          lead: { name: 'Hacked' }
        }, headers: { "ACCEPT" => "application/json" }
        expect(response.status).to be_between(400, 499)

        delete "/api/v1/leads/#{other_lead.id}", headers: { "ACCEPT" => "application/json" }
        expect(response.status).to be_between(400, 499)
      end

      it 'handles invalid lead creation with wrong campaign' do
        other_campaign = create(:campaign, user: other_user)

        post '/api/v1/leads', params: {
          lead: {
            name: 'Test Lead',
            email: 'test@example.com',
            title: 'Title',
            company: 'Company',
            campaignId: other_campaign.id
          }
        }
        expect(response).to have_http_status(:unprocessable_entity)
        errors = JSON.parse(response.body)['errors']
        expect(errors).to include('Campaign not found or unauthorized')
      end
    end
  end

  describe 'Validation Errors' do
    context 'when authenticated' do
      before { sign_in user, scope: :user }

      it 'returns proper error messages for invalid campaign data' do
        # Missing title
        post '/api/v1/campaigns', params: {
          campaign: {
            basePrompt: 'Prompt without title'
          }
        }
        expect(response).to have_http_status(:unprocessable_entity)
        errors = JSON.parse(response.body)['errors']
        expect(errors).to include("Title can't be blank")

        # Missing basePrompt
        post '/api/v1/campaigns', params: {
          campaign: {
            title: 'Title without prompt'
          }
        }
        expect(response).to have_http_status(:unprocessable_entity)
        errors = JSON.parse(response.body)['errors']
        expect(errors).to include("Base prompt can't be blank")
      end

      it 'returns proper error messages for invalid lead data' do
        campaign = create(:campaign, user: user)

        # Missing required fields
        post '/api/v1/leads', params: {
          lead: {
            email: 'test@example.com',
            campaignId: campaign.id
          }
        }
        expect(response).to have_http_status(:unprocessable_entity)
        errors = JSON.parse(response.body)['errors']
        expect(errors).to include("Name can't be blank")
        expect(errors).to include("Title can't be blank")
        expect(errors).to include("Company can't be blank")

        # Invalid email format
        post '/api/v1/leads', params: {
          lead: {
            name: 'Test',
            email: 'invalid-email',
            title: 'Title',
            company: 'Company',
            campaignId: campaign.id
          }
        }
        expect(response).to have_http_status(:unprocessable_entity)
        errors = JSON.parse(response.body)['errors']
        expect(errors).to include("Email is invalid")
      end
    end
  end

  describe 'Malformed Requests' do
    context 'when authenticated' do
      before { sign_in user, scope: :user }

      it 'handles malformed JSON gracefully' do
        # This is handled by Rails framework, but we can test edge cases
        campaign = create(:campaign, user: user)

        # Missing required parameter wrapper
        put "/api/v1/campaigns/#{campaign.id}", params: {
          title: 'Direct param'
        }
        # Rails will handle this, might return 400 or 422
        expect(response.status).to be_between(400, 422)
      end

      it 'handles invalid ID format gracefully' do
        get '/campaigns/abc123'
        expect(response.status).to be_between(300, 499)

        get '/campaigns/123abc'
        expect(response.status).to be_between(300, 499)
      end
    end
  end
end
