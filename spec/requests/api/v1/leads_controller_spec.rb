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

      context 'when lead has agent_outputs referenced by lead_run_steps' do
        let!(:run) { LeadRunPlanner.build!(lead: lead) }
        let!(:step) { run.steps.order(:position).first }
        let!(:agent_output) { create(:agent_output, lead: lead, agent_name: step.agent_name, lead_run: run, lead_run_step: step) }

        before do
          step.update!(agent_output: agent_output)
          # Set current_lead_run_id to test the foreign key constraint clearing
          lead.update!(current_lead_run_id: run.id)
        end

        it 'clears all foreign key references and destroys successfully' do
          expect(step.reload.agent_output_id).to eq(agent_output.id)
          expect(lead.reload.current_lead_run_id).to eq(run.id)

          expect {
            delete "/api/v1/leads/#{lead.id}", headers: { 'Accept' => 'application/json' }
          }.to change(Lead, :count).by(-1)
            .and change(AgentOutput, :count).by(-1)
            .and change(LeadRun, :count).by(-1)
            .and change(LeadRunStep, :count).by(-run.steps.count)

          expect(response).to have_http_status(:no_content)
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

      context 'when requesting SENDER agent on lead with completed DESIGN output' do
        let!(:run) { create(:lead_run, lead: lead, campaign: campaign, status: 'completed') }
        let!(:design_step) do
          create(:lead_run_step, lead_run: run, agent_name: AgentConstants::AGENT_DESIGN, status: 'completed', position: 40)
        end
        let!(:design_output) do
          create(:agent_output,
            lead: lead,
            lead_run: run,
            lead_run_step: design_step,
            agent_name: AgentConstants::AGENT_DESIGN,
            status: 'completed',
            output_data: { 'formatted_email' => 'Subject: Test\n\nBody content' }
          )
        end

        before do
          lead.update!(stage: AgentConstants::STAGE_DESIGNED)
          # Create SENDER agent config
          create(:agent_config, campaign: campaign, agent_name: AgentConstants::AGENT_SENDER, enabled: true)
          # Configure sending (Gmail or SMTP)
          user.update!(gmail_access_token: 'token', gmail_refresh_token: 'refresh', gmail_email: 'test@gmail.com')
          # Ensure API keys are set for run_agents endpoint
          user.update!(llm_api_key: 'test-gemini-key', tavily_api_key: 'test-tavily-key')
        end

        it 'should not return 422 agent_not_next error' do
          # Mock job enqueue
          job_double = double(job_id: 'job-123')
          allow(AgentExecutionJob).to receive(:perform_later).and_return(job_double)

          post "/api/v1/leads/#{lead.id}/run_agents",
               params: { agentName: 'SENDER' },
               headers: { 'Accept' => 'application/json' }

          expect(response).not_to have_http_status(:unprocessable_entity)

          if response.status == 422
            json_response = JSON.parse(response.body)
            # If it fails, it should be a more actionable error, not agent_not_next
            expect(json_response['error']).not_to eq('agent_not_next')
            # Should be sender_not_planned, sending_not_configured, or similar actionable error
            expect(json_response['error']).to be_present
          else
            # Success case: verify run was created with SENDER as next step
            json_response = JSON.parse(response.body)
            expect(json_response['status']).to be_present
            # If a run was created, verify it has SENDER as next step
            if json_response['next_step']
              expect(json_response['next_step']['agent_name']).to eq(AgentConstants::AGENT_SENDER)
            end
          end
        end

        it 'creates a run with SENDER as next step when send-only run is created' do
          # Mock job enqueue to prevent actual execution
          job_double = double(job_id: 'job-123')
          allow(AgentExecutionJob).to receive(:perform_later).and_return(job_double)

          post "/api/v1/leads/#{lead.id}/run_agents",
               params: { agentName: 'SENDER' },
               headers: { 'Accept' => 'application/json' }

          # Should succeed (200 or 202)
          expect([ 200, 202 ]).to include(response.status)

          # Verify a run exists with SENDER step
          lead.reload
          active_run = lead.active_run
          expect(active_run).to be_present
          sender_step = active_run.steps.find_by(agent_name: AgentConstants::AGENT_SENDER)
          expect(sender_step).to be_present
          # Step may be queued (if job not executed) or running (if job executed)
          expect([ 'queued', 'running' ]).to include(sender_step.status)
          expect(sender_step.meta['source_step_id']).to eq(design_step.id)
        end

        it 'returns sender_not_planned when SENDER config is disabled' do
          AgentConfig.find_by(campaign: campaign, agent_name: AgentConstants::AGENT_SENDER).update!(enabled: false)

          post "/api/v1/leads/#{lead.id}/run_agents",
               params: { agentName: 'SENDER' },
               headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:unprocessable_entity)
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('sender_not_planned')
          expect(json_response['reason']).to eq('config_disabled')
        end

        it 'returns run_in_progress when active run has different next step' do
          # Create an active run with WRITER as next step
          active_run = create(:lead_run, lead: lead, campaign: campaign, status: 'running')
          create(:lead_run_step, lead_run: active_run, agent_name: AgentConstants::AGENT_WRITER, status: 'queued', position: 10)
          lead.update!(current_lead_run_id: active_run.id)

          post "/api/v1/leads/#{lead.id}/run_agents",
               params: { agentName: 'SENDER' },
               headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:unprocessable_entity)
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('run_in_progress')
          expect(json_response['nextAgent']).to eq(AgentConstants::AGENT_WRITER)
          expect(json_response['runId']).to eq(active_run.id)
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

  describe 'POST #batch_run_agents' do
    let!(:lead1) { create(:lead, campaign: campaign, stage: 'queued') }
    let!(:lead2) { create(:lead, campaign: campaign, stage: 'queued') }
    let!(:lead3) { create(:lead, campaign: campaign, stage: 'queued') }
    let(:batch_params) do
      {
        leadIds: [ lead1.id, lead2.id, lead3.id ],
        campaignId: campaign.id
      }
    end

    context 'when authenticated' do
      before { sign_in user }

      context 'with valid API keys' do
        before do
          user.update!(llm_api_key: 'test-gemini-key', tavily_api_key: 'test-tavily-key')
        end

        it 'returns accepted status' do
          post '/api/v1/leads/batch_run_agents',
               params: batch_params,
               headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:accepted)
        end

        it 'enqueues jobs for all leads' do
          expect {
            post '/api/v1/leads/batch_run_agents',
                 params: batch_params,
                 headers: { 'Accept' => 'application/json' }
          }.to have_enqueued_job(AgentExecutionJob).at_least(:once)
        end

        it 'returns success response with queued leads' do
          post '/api/v1/leads/batch_run_agents',
               params: batch_params,
               headers: { 'Accept' => 'application/json' }

          json_response = JSON.parse(response.body)
          expect(json_response['success']).to be true
          expect(json_response['total']).to eq(3)
          expect(json_response['queued']).to eq(3)
          expect(json_response['failed']).to eq(0)
          expect(json_response['queuedLeads'].length).to eq(3)
        end

        it 'includes job IDs in response' do
          post '/api/v1/leads/batch_run_agents',
               params: batch_params,
               headers: { 'Accept' => 'application/json' }

          json_response = JSON.parse(response.body)
          expect(json_response['queuedLeads'].all? { |q| q['job_id'].present? }).to be true
        end

        context 'with custom batch size' do
          it 'uses custom batch size' do
            custom_params = batch_params.merge(batchSize: 5)

            post '/api/v1/leads/batch_run_agents',
                 params: custom_params,
                 headers: { 'Accept' => 'application/json' }

            expect(response).to have_http_status(:accepted)
            json_response = JSON.parse(response.body)
            expect(json_response['queued']).to eq(3)
          end
        end
      end

      context 'when API keys are missing' do
        before do
          user.update!(llm_api_key: nil, tavily_api_key: nil)
        end

        it 'returns 422 with error message' do
          post '/api/v1/leads/batch_run_agents',
               params: batch_params,
               headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:unprocessable_entity)
          json_response = JSON.parse(response.body)
          expect(json_response['success']).to be false
          expect(json_response['error']).to be_present
          expect(json_response['total']).to eq(3)
          expect(json_response['queued']).to eq(0)
        end

        it 'does not enqueue any jobs' do
          expect {
            post '/api/v1/leads/batch_run_agents',
                 params: batch_params,
                 headers: { 'Accept' => 'application/json' }
          }.not_to have_enqueued_job(AgentExecutionJob)
        end
      end

      context 'when campaign does not belong to user' do
        let(:other_campaign) { create(:campaign, user: other_user) }
        let(:invalid_params) do
          {
            leadIds: [ lead1.id, lead2.id ],
            campaignId: other_campaign.id
          }
        end

        it 'returns 404 not found' do
          post '/api/v1/leads/batch_run_agents',
               params: invalid_params,
               headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:not_found)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to include('Campaign not found or unauthorized')
        end
      end

      context 'when leadIds is missing' do
        it 'returns 422 with error' do
          invalid_params = { campaignId: campaign.id }

          post '/api/v1/leads/batch_run_agents',
               params: invalid_params,
               headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:unprocessable_entity)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to include('leadIds is required')
        end
      end

      context 'when leadIds is empty array' do
      end

      context 'when campaignId is missing' do
        it 'returns 422 with error' do
          invalid_params = { leadIds: [ lead1.id ] }

          post '/api/v1/leads/batch_run_agents',
               params: invalid_params,
               headers: { 'Accept' => 'application/json' }

          expect(response).to have_http_status(:unprocessable_entity)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to include('campaignId is required')
        end
      end

      context 'with leads from different campaign' do
        let(:other_campaign) { create(:campaign, user: user) }
        let!(:other_lead) { create(:lead, campaign: other_campaign) }

        before do
          user.update!(llm_api_key: 'test-gemini-key', tavily_api_key: 'test-tavily-key')
        end

        it 'filters to only leads from specified campaign' do
          mixed_params = {
            leadIds: [ lead1.id, lead2.id, other_lead.id ],
            campaignId: campaign.id
          }

          post '/api/v1/leads/batch_run_agents',
               params: mixed_params,
               headers: { 'Accept' => 'application/json' }

          json_response = JSON.parse(response.body)
          expect(json_response['total']).to eq(2)  # Only lead1 and lead2
          expect(json_response['queued']).to eq(2)
        end
      end
    end

    context 'when not authenticated' do
      it 'returns 401 unauthorized' do
        post '/api/v1/leads/batch_run_agents',
             params: batch_params,
             headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
