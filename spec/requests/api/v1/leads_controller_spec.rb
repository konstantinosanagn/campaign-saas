require 'rails_helper'

RSpec.describe Api::V1::LeadsController, type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:campaign) { create(:campaign, user: user) }
  let(:other_campaign) { create(:campaign, user: other_user) }
  let(:valid_attributes) do
    {
      lead: {
        name: 'John Doe',
        email: 'john@example.com',
        title: 'VP Marketing',
        company: 'Example Corp',
        campaignId: campaign.id
      }
    }
  end

  describe 'GET #index' do
    context 'when authenticated' do
      before { sign_in user }

      it 'returns only leads from current user\'s campaigns' do
        lead1 = create(:lead, campaign: campaign)
        lead2 = create(:lead, campaign: campaign)
        create(:lead, campaign: other_campaign) # Should not be included

        get '/api/v1/leads', headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response.length).to eq(2)
        expect(json_response.map { |l| l['id'] }).to contain_exactly(lead1.id, lead2.id)
      end

      it 'returns empty array when user has no leads' do
        get '/api/v1/leads', headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response).to eq([])
      end
    end

    context 'when not authenticated' do
      it 'returns 401 unauthorized' do
        get '/api/v1/leads', headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST #create' do
    context 'when authenticated' do
      before { sign_in user }

      context 'with valid attributes' do
        it 'creates a new lead' do
          expect {
            post '/api/v1/leads', params: valid_attributes, headers: { 'Accept' => 'application/json' }
          }.to change(Lead, :count).by(1)
        end

        it 'associates lead with campaign' do
          post '/api/v1/leads', params: valid_attributes, headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:created)
          lead = Lead.last
          expect(lead.campaign).to eq(campaign)
        end

        it 'returns the created lead' do
          post '/api/v1/leads', params: valid_attributes, headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:created)
          json_response = JSON.parse(response.body)
          expect(json_response['name']).to eq('John Doe')
          expect(json_response['email']).to eq('john@example.com')
          expect(json_response['campaignId']).to eq(campaign.id)
        end

        it 'converts camelCase to snake_case' do
          post '/api/v1/leads', params: valid_attributes, headers: { 'Accept' => 'application/json' }

          lead = Lead.last
          expect(lead.campaign_id).to eq(campaign.id)
        end

        it 'sets default website from email when not provided' do
          attributes = valid_attributes.dup
          attributes[:lead].delete(:website)

          post '/api/v1/leads', params: attributes, headers: { 'Accept' => 'application/json' }

          lead = Lead.last
          expect(lead.website).to eq('example.com')
        end

        it 'sets default stage to queued' do
          post '/api/v1/leads', params: valid_attributes, headers: { 'Accept' => 'application/json' }

          lead = Lead.last
          expect(lead.stage).to eq('queued')
        end

        it 'sets default quality to "-"' do
          post '/api/v1/leads', params: valid_attributes, headers: { 'Accept' => 'application/json' }

          lead = Lead.last
          expect(lead.quality).to eq('-')
        end
      end

      context 'with invalid attributes' do
        it 'returns 422 with errors when name is missing' do
          invalid_attributes = valid_attributes.dup
          invalid_attributes[:lead][:name] = nil

          post '/api/v1/leads', params: invalid_attributes, headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:unprocessable_entity)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to be_present
        end

        it 'returns 422 with errors when email is invalid' do
          invalid_attributes = valid_attributes.dup
          invalid_attributes[:lead][:email] = 'invalid-email'

          post '/api/v1/leads', params: invalid_attributes, headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:unprocessable_entity)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to be_present
        end
      end

      context 'when campaign belongs to another user' do
        it 'returns 422 unauthorized' do
          invalid_attributes = valid_attributes.dup
          invalid_attributes[:lead][:campaignId] = other_campaign.id

          post '/api/v1/leads', params: invalid_attributes, headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:unprocessable_entity)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to include('Campaign not found or unauthorized')
        end
      end
    end

    context 'when not authenticated' do
      it 'returns 401 unauthorized' do
        post '/api/v1/leads', params: valid_attributes, headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT #update' do
    let!(:lead) { create(:lead, campaign: campaign) }
    let(:update_attributes) do
      {
        lead: {
          name: 'Jane Doe',
          email: 'jane@example.com',
          title: 'Head of Sales',
          company: 'New Company'
        }
      }
    end

    context 'when authenticated' do
      before { sign_in user }

      context 'with valid attributes' do
        it 'updates the lead' do
          put "/api/v1/leads/#{lead.id}", params: update_attributes, headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:success)
          lead.reload
          expect(lead.name).to eq('Jane Doe')
          expect(lead.email).to eq('jane@example.com')
          expect(lead.title).to eq('Head of Sales')
          expect(lead.company).to eq('New Company')
        end

        it 'returns the updated lead' do
          put "/api/v1/leads/#{lead.id}", params: update_attributes, headers: { 'Accept' => 'application/json' }

          json_response = JSON.parse(response.body)
          expect(json_response['name']).to eq('Jane Doe')
          expect(json_response['email']).to eq('jane@example.com')
        end
      end

      context 'with invalid attributes' do
        it 'returns 422 with errors' do
          invalid_attributes = update_attributes.dup
          invalid_attributes[:lead][:email] = 'invalid-email'

          put "/api/v1/leads/#{lead.id}", params: invalid_attributes, headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:unprocessable_entity)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to be_present
        end
      end

      context 'when lead belongs to another user\'s campaign' do
        let!(:other_lead) { create(:lead, campaign: other_campaign) }

        it 'returns 422 unauthorized' do
          put "/api/v1/leads/#{other_lead.id}", params: update_attributes, headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:unprocessable_entity)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to include('Not found or unauthorized')
        end
      end

      context 'when lead does not exist' do
        it 'returns 422' do
          put '/api/v1/leads/99999', params: update_attributes, headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:unprocessable_entity)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to include('Not found or unauthorized')
        end
      end
    end

    context 'when not authenticated' do
      it 'returns 401 unauthorized' do
        put "/api/v1/leads/#{lead.id}", params: update_attributes, headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:lead) { create(:lead, campaign: campaign) }

    context 'when authenticated' do
      before { sign_in user }

      it 'destroys the lead' do
        expect {
          delete "/api/v1/leads/#{lead.id}", headers: { 'Accept' => 'application/json' }
        }.to change(Lead, :count).by(-1)
      end

      it 'returns 204 no content' do
        delete "/api/v1/leads/#{lead.id}", headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:no_content)
      end

      context 'when lead belongs to another user\'s campaign' do
        let!(:other_lead) { create(:lead, campaign: other_campaign) }

        it 'returns 404 not found' do
          delete "/api/v1/leads/#{other_lead.id}", headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:not_found)
          expect(Lead.find_by(id: other_lead.id)).to be_present
        end
      end

      context 'when lead does not exist' do
        it 'returns 404' do
          delete '/api/v1/leads/99999', headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'when not authenticated' do
      it 'returns 401 unauthorized' do
        delete "/api/v1/leads/#{lead.id}", headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST #run_agents' do
    let!(:lead) { create(:lead, campaign: campaign, email: 'john@example.com', company: 'Example Corp') }

    context 'when authenticated' do
      before { sign_in user }

      context 'with valid API keys' do
        before do
          user.update!(llm_api_key: 'test-gemini-key', tavily_api_key: 'test-tavily-key')
        end

        it 'returns success status' do
          # Mock the agent services to avoid actual API calls
          allow_any_instance_of(Agents::SearchAgent).to receive(:run).and_return({
            company: 'Example Corp',
            sources: [ { title: 'Test Source', url: 'http://example.com' } ],
            image: 'http://example.com/image.jpg'
          })

          allow_any_instance_of(Agents::WriterAgent).to receive(:run).and_return({
            company: 'Example Corp',
            email: 'Subject: Test Email\n\nBody content'
          })

          allow_any_instance_of(Agents::CritiqueAgent).to receive(:run).and_return({
            'critique' => nil
          })

          post "/api/v1/leads/#{lead.id}/run_agents", headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:ok)
          json_response = JSON.parse(response.body)
          expect(json_response['status']).to be_present
        end

        it 'creates agent output for the next agent' do
          # Mock the agent services
          allow_any_instance_of(Agents::SearchAgent).to receive(:run).and_return({
            company: 'Example Corp',
            sources: []
          })

          allow_any_instance_of(Agents::WriterAgent).to receive(:run).and_return({
            company: 'Example Corp',
            email: 'Test email content'
          })

          allow_any_instance_of(Agents::CritiqueAgent).to receive(:run).and_return({
            'critique' => nil
          })

          expect {
            post "/api/v1/leads/#{lead.id}/run_agents", headers: { 'Accept' => 'application/json' }
          }.to change(AgentOutput, :count).by(1)  # Only SEARCH agent runs for a queued lead
        end

        it 'updates lead stage to next stage' do
          # Mock the agent services
          allow_any_instance_of(Agents::SearchAgent).to receive(:run).and_return({
            company: 'Example Corp',
            sources: []
          })

          allow_any_instance_of(Agents::WriterAgent).to receive(:run).and_return({
            company: 'Example Corp',
            email: 'Test email'
          })

          allow_any_instance_of(Agents::CritiqueAgent).to receive(:run).and_return({
            'critique' => nil
          })

          post "/api/v1/leads/#{lead.id}/run_agents", headers: { 'Accept' => 'application/json' }

          lead.reload
          expect(lead.stage).to eq('searched')  # Only advances to next stage (searched for queued lead)
        end
      end

      context 'when API keys are missing' do
        before do
          user.update!(llm_api_key: nil, tavily_api_key: nil)
        end

        it 'returns 422 with error message' do
          post "/api/v1/leads/#{lead.id}/run_agents", headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:unprocessable_entity)
          json_response = JSON.parse(response.body)
          expect(json_response['status']).to eq('failed')
          expect(json_response['error']).to be_present
        end
      end

      context 'when lead belongs to another user' do
        let!(:other_lead) { create(:lead, campaign: other_campaign) }

        it 'returns 404 not found' do
          post "/api/v1/leads/#{other_lead.id}/run_agents", headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:not_found)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to include('Lead not found or unauthorized')
        end
      end

      context 'when lead does not exist' do
        it 'returns 404 not found' do
          post '/api/v1/leads/99999/run_agents', headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'when not authenticated' do
      it 'returns 401 unauthorized' do
        post "/api/v1/leads/#{lead.id}/run_agents", headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET #agent_outputs' do
    let!(:lead) { create(:lead, campaign: campaign) }

    context 'when authenticated' do
      before { sign_in user }

      context 'when lead has agent outputs' do
        let!(:search_output) { create(:agent_output, lead: lead, agent_name: 'SEARCH', status: 'completed', output_data: { sources: [] }) }
        let!(:writer_output) { create(:agent_output, lead: lead, agent_name: 'WRITER', status: 'completed', output_data: { email: 'Test email' }) }

        it 'returns all agent outputs for the lead' do
          get "/api/v1/leads/#{lead.id}/agent_outputs", headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:ok)
          json_response = JSON.parse(response.body)
          expect(json_response['leadId']).to eq(lead.id)
          expect(json_response['outputs'].length).to eq(2)
          expect(json_response['outputs'].map { |o| o['agentName'] }).to contain_exactly('SEARCH', 'WRITER')
        end

        it 'includes output data in the response' do
          get "/api/v1/leads/#{lead.id}/agent_outputs", headers: { 'Accept' => 'application/json' }

          json_response = JSON.parse(response.body)
          search_output_json = json_response['outputs'].find { |o| o['agentName'] == 'SEARCH' }
          expect(search_output_json['outputData']).to be_present
        end
      end

      context 'when lead has no agent outputs' do
        it 'returns empty outputs array' do
          get "/api/v1/leads/#{lead.id}/agent_outputs", headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:ok)
          json_response = JSON.parse(response.body)
          expect(json_response['leadId']).to eq(lead.id)
          expect(json_response['outputs']).to eq([])
        end
      end

      context 'when lead belongs to another user' do
        let!(:other_lead) { create(:lead, campaign: other_campaign) }

        it 'returns 404 not found' do
          get "/api/v1/leads/#{other_lead.id}/agent_outputs", headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:not_found)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to include('Lead not found or unauthorized')
        end
      end

      context 'when lead does not exist' do
        it 'returns 404 not found' do
          get '/api/v1/leads/99999/agent_outputs', headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'when not authenticated' do
      it 'returns 401 unauthorized' do
        get "/api/v1/leads/#{lead.id}/agent_outputs", headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
