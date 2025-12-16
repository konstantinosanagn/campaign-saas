require "rails_helper"

RSpec.describe Api::V1::LeadsController, type: :controller do
  let(:user) { create(:user) }
  let(:campaign) { create(:campaign, user: user) }

  before do
    allow_any_instance_of(Api::V1::BaseController).to receive(:skip_auth?).and_return(true)
    allow_any_instance_of(Api::V1::BaseController).to receive(:current_user).and_return(user)
  end

  describe "GET #index" do
    it "returns leads belonging to current_user" do
      lead1 = create(:lead, campaign: campaign)
      lead2 = create(:lead, campaign: campaign)

      get :index

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.length).to eq(2)
      expect(body.map { |l| l["id"] }).to contain_exactly(lead1.id, lead2.id)
    end
  end

  describe "POST #create" do
    let(:params) { { lead: { name: "Bob", campaignId: 10 } } }

    it "returns 422 when campaign not found or unauthorized" do
      campaigns = double(find_by: nil)
      allow(user).to receive(:campaigns).and_return(campaigns)

      post :create, params: params

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["errors"]).to include(/Campaign not found/)
    end

    it "creates lead when campaign belongs to user" do
      lead_double = instance_double("Lead", save: true, id: 1, name: "Bob", email: "bob@example.com", title: "CEO", company: "Acme", website: "", campaign_id: 10, stage: "queued", quality: "-", created_at: Time.current, updated_at: Time.current)
      campaign_double = double(leads: double(build: lead_double))
      campaigns = double(find_by: campaign_double)
      allow(user).to receive(:campaigns).and_return(campaigns)
      allow(LeadSerializer).to receive(:serialize).with(lead_double).and_return({
        "id" => 1, "name" => "Bob", "campaignId" => 10
      })

      post :create, params: params

      expect(response).to have_http_status(:created)
    end

    it "returns errors when lead save fails" do
      lead_double = instance_double("Lead", save: false, errors: double(full_messages: [ "error" ]))
      campaign_double = double(leads: double(build: lead_double))
      campaigns = double(find_by: campaign_double)
      allow(user).to receive(:campaigns).and_return(campaigns)

      post :create, params: params

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["errors"]).to include("error")
    end
  end

  describe "PATCH #update" do
    let(:lead_id) { 123 }
    let(:params) { { id: lead_id, lead: { name: "John" } } }

    it "updates lead when found and authorized" do
      lead = double(update: true, id: lead_id, name: "John", email: "john@example.com", title: "CTO", company: "Tech", website: "", campaign_id: 1, stage: "queued", quality: "-", created_at: Time.current, updated_at: Time.current)
      allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(lead)
      allow(LeadSerializer).to receive(:serialize).with(lead).and_return({
        "id" => lead_id, "name" => "John", "campaignId" => 1
      })

      patch :update, params: params

      expect(response).to have_http_status(:ok)
    end

    it "returns errors when update fails" do
      lead = double(update: false, errors: double(full_messages: [ "error" ]))
      allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(lead)

      patch :update, params: params

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["errors"]).to include("error")
    end

    it "returns not found when lead missing or unauthorized" do
      allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(nil)

      patch :update, params: params

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["errors"]).to include(/Not found or unauthorized/)
    end
  end

  describe "DELETE #destroy" do
    let(:lead_id) { 99 }

    it "destroys lead when found" do
      lead = double(destroy: true)
      allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(lead)

      delete :destroy, params: { id: lead_id }

      expect(response).to have_http_status(:no_content)
    end

    it "returns not found when missing" do
      allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(nil)

      delete :destroy, params: { id: lead_id }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST #run_agents" do
    let(:lead) { create(:lead, campaign: campaign, stage: "queued") }

    before do
      user.update!(llm_api_key: "test-key", tavily_api_key: "test-key")
    end

    it "returns not found when lead missing" do
      post :run_agents, params: { id: 99999 }, format: :json

      expect(response).to have_http_status(:not_found)
    end

    it "queues job when async and perform_later returns job" do
      job_double = double(job_id: "abc")
      allow(AgentExecutionJob).to receive(:perform_later).and_return(job_double)

      post :run_agents, params: { id: lead.id, async: "true" }, format: :json

      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("queued")
      expect(body["jobId"]).to eq("abc")
    end

    it "handles enqueue errors and returns 500" do
      allow(AgentExecutionJob).to receive(:perform_later).and_raise("nope")

      post :run_agents, params: { id: lead.id, async: "true" }, format: :json

      expect(response).to have_http_status(:internal_server_error)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("error")
    end

    it "returns unprocessable when API keys are missing in sync mode" do
      allow(ApiKeyService).to receive(:keys_available?).and_return(false)
      allow(ApiKeyService).to receive(:missing_keys).and_return([ "GEMINI_API_KEY" ])

      post :run_agents, params: { id: lead.id, async: "false" }, format: :json

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("failed")
      expect(body["error"]).to match(/Missing API keys/i)
    end

    it "runs sync and returns ok when executor runs" do
      allow(ApiKeyService).to receive(:keys_available?).and_return(true)
      allow(LeadRunExecutor).to receive(:run_next!).and_return({ result_type: :claimed })

      post :run_agents, params: { id: lead.id, async: "false" }, format: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("completed")
    end

    it "handles exceptions during sync and returns 500" do
      allow(ApiKeyService).to receive(:keys_available?).and_return(true)
      allow(LeadRunExecutor).to receive(:run_next!).and_raise("error")

      post :run_agents, params: { id: lead.id, async: "false" }, format: :json

      expect(response).to have_http_status(:internal_server_error)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("error")
    end

    it "returns 503 when execution is paused (but still plans a run)" do
      allow(AgentExecution).to receive(:paused?).and_return(true)
      allow(ApiKeyService).to receive(:keys_available?).and_return(true)

      expect(AgentExecutionJob).not_to receive(:perform_later)
      expect(LeadRunExecutor).not_to receive(:run_next!)

      post :run_agents, params: { id: lead.id, async: "true" }, format: :json

      expect(response).to have_http_status(:service_unavailable)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("failed")
      expect(body["error"]).to eq("execution_paused")

      lead.reload
      expect(lead.current_lead_run_id).to be_present
    end

    it "defaults to async in production when async param not provided" do
      allow(Rails.env).to receive(:production?).and_return(true)
      job_double = double(job_id: "job")
      allow(AgentExecutionJob).to receive(:perform_later).and_return(job_double)

      post :run_agents, params: { id: lead.id }, format: :json

      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      expect(body["jobId"]).to eq("job")
    end
  end

  describe "GET #agent_outputs" do
    let(:lead) { create(:lead, campaign: campaign) }

    it "returns 404 when lead missing" do
      get :agent_outputs, params: { id: 99999 }, format: :json

      expect(response).to have_http_status(:not_found)
    end

    it "returns outputs mapping when present" do
      output = create(:agent_output,
        lead: lead,
        agent_name: "SEARCH",
        status: "completed",
        output_data: { "sources" => [] }
      )

      get :agent_outputs, params: { id: lead.id }, format: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["leadId"]).to eq(lead.id)
      expect(body["outputs"].first["agentName"]).to eq("SEARCH")
    end
  end

  describe "POST #send_email" do
    let(:lead) { create(:lead, campaign: campaign) }

    before do
      # Create SENDER agent config
      create(:agent_config, campaign: campaign, agent_name: AgentConstants::AGENT_SENDER, enabled: true)
      # Configure email sending
      user.update!(gmail_access_token: 'token', gmail_refresh_token: 'refresh', gmail_email: 'test@gmail.com')
    end

    it "returns 404 when lead missing" do
      post :send_email, params: { id: 99999 }

      expect(response).to have_http_status(:not_found)
      body = JSON.parse(response.body)
      expect(body["errors"]).to include(/Lead not found or unauthorized/)
    end

    it "returns success when send_email succeeds" do
      # Create a completed DESIGN output for the lead
      run = create(:lead_run, lead: lead, campaign: campaign, status: 'completed')
      design_step = create(:lead_run_step, lead_run: run, agent_name: AgentConstants::AGENT_DESIGN, status: 'completed', position: 40)
      create(:agent_output,
        lead: lead,
        lead_run: run,
        lead_run_step: design_step,
        agent_name: AgentConstants::AGENT_DESIGN,
        status: 'completed',
        output_data: { 'formatted_email' => 'Subject: Test\n\nBody content' }
      )

      # Mock job enqueue
      job_double = double(job_id: 'job-123')
      allow(AgentExecutionJob).to receive(:perform_later).and_return(job_double)

      post :send_email, params: { id: lead.id }

      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      expect(body["success"]).to be true
      expect(body["message"]).to eq("Email sending queued")
      expect(body["jobId"]).to eq("job-123")
    end

    it "returns error when sending is not configured" do
      # Remove Gmail configuration
      user.update!(gmail_access_token: nil, gmail_refresh_token: nil, gmail_email: nil)

      # Create a completed DESIGN output for the lead
      run = create(:lead_run, lead: lead, campaign: campaign, status: 'completed')
      design_step = create(:lead_run_step, lead_run: run, agent_name: AgentConstants::AGENT_DESIGN, status: 'completed', position: 40)
      create(:agent_output,
        lead: lead,
        lead_run: run,
        lead_run_step: design_step,
        agent_name: AgentConstants::AGENT_DESIGN,
        status: 'completed',
        output_data: { 'formatted_email' => 'Subject: Test\n\nBody content' }
      )

      post :send_email, params: { id: lead.id }

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["success"]).to be false
      expect(body["error"]).to eq("sending_not_configured")
    end

    it "handles exceptions raised during send_email" do
      # Create a completed DESIGN output for the lead
      run = create(:lead_run, lead: lead, campaign: campaign, status: 'completed')
      design_step = create(:lead_run_step, lead_run: run, agent_name: AgentConstants::AGENT_DESIGN, status: 'completed', position: 40)
      create(:agent_output,
        lead: lead,
        lead_run: run,
        lead_run_step: design_step,
        agent_name: AgentConstants::AGENT_DESIGN,
        status: 'completed',
        output_data: { 'formatted_email' => 'Subject: Test\n\nBody content' }
      )

      # Mock LeadRuns.ensure_sendable_run! to raise an error
      allow(LeadRuns).to receive(:ensure_sendable_run!).and_raise(StandardError, "Network error")

      post :send_email, params: { id: lead.id }

      expect(response).to have_http_status(:internal_server_error)
      body = JSON.parse(response.body)
      expect(body["success"]).to be false
      expect(body["error"]).to eq("Network error")
    end
  end

  describe "PATCH #update_agent_output" do
    let(:lead) { create(:lead, campaign: campaign) }

    it "returns 404 when lead missing" do
      patch :update_agent_output, params: { id: 99999 }, format: :json

      expect(response).to have_http_status(:not_found)
    end

    it "requires agentName param" do
      patch :update_agent_output, params: { id: lead.id }, format: :json

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["errors"]).to include(/Agent name is required/)
    end

    it "rejects unsupported agent names" do
      patch :update_agent_output, params: { id: lead.id, agentName: "UNKNOWN" }, format: :json

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["errors"]).to include(/Only WRITER, SEARCH, and DESIGN agent outputs can be updated/)
    end

    it "returns not found when agent output missing" do
      patch :update_agent_output, params: { id: lead.id, agentName: AgentConstants::AGENT_WRITER }, format: :json

      expect(response).to have_http_status(:not_found)
    end

    context "when updating WRITER" do
      let!(:writer_output) do
        create(:agent_output,
          lead: lead,
          agent_name: AgentConstants::AGENT_WRITER,
          status: "completed",
          output_data: { "email" => "old email" }
        )
      end

      it "requires content and updates successfully" do
        patch :update_agent_output, params: { id: lead.id, agentName: AgentConstants::AGENT_WRITER, content: "hi" }, format: :json

        expect(response).to have_http_status(:ok)
        writer_output.reload
        expect(writer_output.output_data["email"]).to eq("hi")
      end

      it "accepts email param as alternative to content" do
        patch :update_agent_output, params: { id: lead.id, agentName: AgentConstants::AGENT_WRITER, email: "email-content" }, format: :json

        expect(response).to have_http_status(:ok)
        writer_output.reload
        expect(writer_output.output_data["email"]).to eq("email-content")
      end

      it "returns unprocessable when content missing for WRITER" do
        patch :update_agent_output, params: { id: lead.id, agentName: AgentConstants::AGENT_WRITER }, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["errors"]).to include(/Email content is required/)
      end
    end

    context "when updating DESIGN" do
      let!(:design_output) do
        create(:agent_output,
          lead: lead,
          agent_name: AgentConstants::AGENT_DESIGN,
          status: "completed",
          output_data: { "formatted_email" => "old formatted email" }
        )
      end

      it "requires content and updates with formatted_email" do
        patch :update_agent_output, params: { id: lead.id, agentName: AgentConstants::AGENT_DESIGN, content: "hi" }, format: :json

        expect(response).to have_http_status(:ok)
        design_output.reload
        expect(design_output.output_data["formatted_email"]).to eq("hi")
        expect(design_output.output_data["email"]).to eq("hi")
      end

      it "accepts email param as alternative to content" do
        patch :update_agent_output, params: { id: lead.id, agentName: AgentConstants::AGENT_DESIGN, email: "email-content" }, format: :json

        expect(response).to have_http_status(:ok)
        design_output.reload
        expect(design_output.output_data["email"]).to eq("email-content")
        expect(design_output.output_data["formatted_email"]).to eq("email-content")
      end

      it "accepts formatted_email param as alternative to content" do
        patch :update_agent_output, params: { id: lead.id, agentName: AgentConstants::AGENT_DESIGN, formatted_email: "formatted-content" }, format: :json

        expect(response).to have_http_status(:ok)
        design_output.reload
        expect(design_output.output_data["formatted_email"]).to eq("formatted-content")
        expect(design_output.output_data["email"]).to eq("formatted-content")
      end

      it "returns unprocessable when content missing for DESIGN" do
        patch :update_agent_output, params: { id: lead.id, agentName: AgentConstants::AGENT_DESIGN }, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["errors"]).to include(/Email content is required/)
      end
    end

    context "when updating SEARCH" do
      let!(:search_output) do
        create(:agent_output,
          lead: lead,
          agent_name: AgentConstants::AGENT_SEARCH,
          status: "completed",
          output_data: { "sources" => [] }
        )
      end

      it "requires updatedData and updates successfully" do
        patch :update_agent_output, params: { id: lead.id, agentName: AgentConstants::AGENT_SEARCH, updatedData: { foo: "bar" } }, format: :json

        expect(response).to have_http_status(:ok)
        search_output.reload
        expect(search_output.output_data["foo"]).to eq("bar")
      end

      it "accepts updated_data (snake_case) as alternative to updatedData" do
        patch :update_agent_output, params: { id: lead.id, agentName: AgentConstants::AGENT_SEARCH, updated_data: { baz: "qux" } }, format: :json

        expect(response).to have_http_status(:ok)
        search_output.reload
        expect(search_output.output_data["baz"]).to eq("qux")
      end

      it "returns unprocessable when updatedData missing for SEARCH" do
        patch :update_agent_output, params: { id: lead.id, agentName: AgentConstants::AGENT_SEARCH }, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["errors"]).to include(/Updated data is required for SEARCH agent/)
      end
    end
  end
end
