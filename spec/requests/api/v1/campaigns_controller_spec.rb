require 'rails_helper'

RSpec.describe Api::V1::CampaignsController, type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:valid_attributes) do
    {
      campaign: {
        title: 'Test Campaign',
        sharedSettings: {
          brand_voice: {
            tone: 'professional',
            persona: 'founder'
          },
          primary_goal: 'book_call'
        }
      }
    }
  end

  describe 'GET #index' do
    context 'when authenticated' do
      before { sign_in user }

      it 'returns only the current user\'s campaigns' do
        campaign1 = create(:campaign, user: user)
        campaign2 = create(:campaign, user: user)
        create(:campaign, user: other_user) # Should not be included

        get '/api/v1/campaigns', headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response.length).to eq(2)
        expect(json_response.map { |c| c['id'] }).to contain_exactly(campaign1.id, campaign2.id)
      end

      it 'returns empty array when user has no campaigns' do
        get '/api/v1/campaigns', headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response).to eq([])
      end
    end

    context 'when not authenticated' do
      it 'returns 401 unauthorized' do
        get '/api/v1/campaigns', headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST #create' do
    context 'when authenticated' do
      before { sign_in user }

      context 'with valid attributes' do
        it 'creates a new campaign' do
          expect {
            post '/api/v1/campaigns', params: valid_attributes, headers: { 'Accept' => 'application/json' }
          }.to change(Campaign, :count).by(1)
        end

        it 'associates campaign with current user' do
          post '/api/v1/campaigns', params: valid_attributes, headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:created)
          campaign = Campaign.last
          expect(campaign.user).to eq(user)
        end

        it 'returns the created campaign' do
          post '/api/v1/campaigns', params: valid_attributes, headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:created)
          json_response = JSON.parse(response.body)
          expect(json_response['title']).to eq('Test Campaign')
          expect(json_response['sharedSettings']).to be_a(Hash)
          expect(json_response['sharedSettings']['brand_voice']).to be_a(Hash)
        end

        it 'converts camelCase to snake_case' do
          post '/api/v1/campaigns', params: valid_attributes, headers: { 'Accept' => 'application/json' }

          campaign = Campaign.last
          expect(campaign.title).to eq('Test Campaign')
          expect(campaign.shared_settings).to be_a(Hash)
          expect(campaign.shared_settings['brand_voice']).to be_a(Hash)
        end
      end

      context 'with invalid attributes' do
        it 'returns 422 with errors when title is missing' do
          invalid_attributes = {
            campaign: {
              sharedSettings: {
                brand_voice: { tone: 'professional', persona: 'founder' },
                primary_goal: 'book_call'
              }
            }
          }

          post '/api/v1/campaigns', params: invalid_attributes, headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:unprocessable_entity)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to be_present
        end
      end
    end

    context 'when not authenticated' do
      it 'returns 401 unauthorized' do
        post '/api/v1/campaigns', params: valid_attributes, headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT #update' do
    let!(:campaign) { create(:campaign, user: user) }
    let(:update_attributes) do
      {
        campaign: {
          title: 'Updated Campaign',
          sharedSettings: {
            brand_voice: {
              tone: 'friendly',
              persona: 'sales'
            },
            primary_goal: 'demo_request'
          }
        }
      }
    end

    context 'when authenticated' do
      before { sign_in user }

      context 'with valid attributes' do
        it 'updates the campaign' do
          put "/api/v1/campaigns/#{campaign.id}", params: update_attributes, headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:success)
          campaign.reload
          expect(campaign.title).to eq('Updated Campaign')
          expect(campaign.shared_settings['brand_voice']['tone']).to eq('friendly')
        end

        it 'returns the updated campaign' do
          put "/api/v1/campaigns/#{campaign.id}", params: update_attributes, headers: { 'Accept' => 'application/json' }

          json_response = JSON.parse(response.body)
          expect(json_response['title']).to eq('Updated Campaign')
          expect(json_response['sharedSettings']).to be_a(Hash)
          expect(json_response['sharedSettings']['brand_voice']['tone']).to eq('friendly')
        end
      end

      context 'with invalid attributes' do
        it 'returns 422 with errors' do
          invalid_attributes = {
            campaign: {
              title: ''
            }
          }

          put "/api/v1/campaigns/#{campaign.id}", params: invalid_attributes, headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:unprocessable_entity)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to be_present
        end
      end

      context 'when campaign belongs to another user' do
        let!(:other_campaign) { create(:campaign, user: other_user) }

        it 'returns 422 unauthorized' do
          put "/api/v1/campaigns/#{other_campaign.id}", params: update_attributes, headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:unprocessable_entity)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to include('Not found or unauthorized')
        end
      end

      context 'when campaign does not exist' do
        it 'returns 422' do
          put '/api/v1/campaigns/99999', params: update_attributes, headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:unprocessable_entity)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to include('Not found or unauthorized')
        end
      end
    end

    context 'when not authenticated' do
      it 'returns 401 unauthorized' do
        put "/api/v1/campaigns/#{campaign.id}", params: update_attributes, headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:campaign) { create(:campaign, user: user) }

    context 'when authenticated' do
      before { sign_in user }

      it 'destroys the campaign' do
        expect {
          delete "/api/v1/campaigns/#{campaign.id}", headers: { 'Accept' => 'application/json' }
        }.to change(Campaign, :count).by(-1)
      end

      it 'returns 204 no content' do
        delete "/api/v1/campaigns/#{campaign.id}", headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:no_content)
      end

      it 'destroys associated leads' do
        lead = create(:lead, campaign: campaign)

        expect {
          delete "/api/v1/campaigns/#{campaign.id}", headers: { 'Accept' => 'application/json' }
        }.to change(Lead, :count).by(-1)
      end

      context 'when campaign belongs to another user' do
        let!(:other_campaign) { create(:campaign, user: other_user) }

        it 'returns 404 not found' do
          delete "/api/v1/campaigns/#{other_campaign.id}", headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:not_found)
          expect(Campaign.find_by(id: other_campaign.id)).to be_present
        end
      end

      context 'when campaign does not exist' do
        it 'returns 404' do
          delete '/api/v1/campaigns/99999', headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'when not authenticated' do
      it 'returns 401 unauthorized' do
        delete "/api/v1/campaigns/#{campaign.id}", headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
