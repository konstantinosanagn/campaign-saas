require "rails_helper"

RSpec.describe Api::V1::LeadsController, type: :controller do
  let(:user) { instance_double("User", id: 1) }

  before do
    allow_any_instance_of(Api::V1::BaseController).to receive(:skip_auth?).and_return(true)
    allow_any_instance_of(Api::V1::BaseController).to receive(:current_user).and_return(user)
  end

  describe "GET #index" do
    it "returns leads belonging to current_user" do
      leads = [ double(id: 1), double(id: 2) ]
      allow(Lead).to receive_message_chain(:includes, :joins, :where).and_return(leads)
      allow(LeadSerializer).to receive(:serialize_collection).with(leads).and_return([
        { "id" => 1, "name" => "Lead 1" },
        { "id" => 2, "name" => "Lead 2" }
      ])

      get :index

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.length).to eq(2)
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
    let(:lead) { double(id: 5, campaign: double(id: 7)) }

    before do
      allow(ApiKeyService).to receive(:keys_available?).with(user).and_return(true)
    end

    it "returns not found when lead missing" do
      allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(nil)

      post :run_agents, params: { id: 1 }

      expect(response).to have_http_status(:not_found)
    end

    it "queues job when async and perform_later returns job" do
      allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(lead)
      allow(AgentExecutionJob).to receive(:perform_later).and_return(double(job_id: "abc"))
      allow(LeadSerializer).to receive(:serialize).with(lead).and_return({
        "id" => 5, "name" => "Test Lead", "campaignId" => 7
      })

      post :run_agents, params: { id: 1, async: "true" }

      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("queued")
      expect(body["jobId"]).to eq("abc")
    end

    it "handles enqueue errors and returns 500" do
      allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(lead)
      allow(AgentExecutionJob).to receive(:perform_later).and_raise("nope")

      post :run_agents, params: { id: 1, async: "true" }

      expect(response).to have_http_status(:internal_server_error)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("error")
    end

    it "runs sync and returns unprocessable when result failed" do
      result = { status: "failed", error: "error" }
      allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(lead)
      allow(LeadAgentService).to receive(:run_agents_for_lead).and_return(result)
      allow(LeadSerializer).to receive(:serialize).with(lead).and_return({
        "id" => 5, "name" => "Test Lead", "campaignId" => 7
      })

      post :run_agents, params: { id: 1, async: "false" }

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("error")
    end

    it "runs sync and returns ok on success" do
      result = { status: "completed", outputs: {}, completed_agents: [ "SEARCH", "WRITER" ], failed_agents: [] }
      allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(lead)
      allow(LeadAgentService).to receive(:run_agents_for_lead).and_return(result)
      allow(LeadSerializer).to receive(:serialize).with(lead).and_return({
        "id" => 5, "name" => "Test Lead", "campaignId" => 7
      })

      post :run_agents, params: { id: 1, async: "false" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("completed")
    end

    it "handles exceptions during sync and returns 500" do
      allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(lead)
      allow(LeadAgentService).to receive(:run_agents_for_lead).and_raise("error")

      post :run_agents, params: { id: 1, async: "false" }

      expect(response).to have_http_status(:internal_server_error)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("error")
    end

    it "defaults to async in production when async param not provided" do
      allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(lead)
      allow(Rails.env).to receive(:production?).and_return(true)
      allow(AgentExecutionJob).to receive(:perform_later).and_return(double(job_id: "job"))
      allow(LeadSerializer).to receive(:serialize).with(lead).and_return({
        "id" => 5, "name" => "Test Lead", "campaignId" => 7
      })

      post :run_agents, params: { id: 1 }

      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      expect(body["jobId"]).to eq("job")
    end
  end

  describe "GET #agent_outputs" do
    it "returns 404 when lead missing" do
      allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(nil)

      get :agent_outputs, params: { id: 1 }

      expect(response).to have_http_status(:not_found)
    end

    it "returns outputs mapping when present" do
      output = double(agent_name: "A", status: "ok", output_data: { a: 1 }, error_message: nil, created_at: Time.now, updated_at: Time.now)
      lead = double(id: 2, agent_outputs: [ output ])
      allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(lead)

      get :agent_outputs, params: { id: 1 }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["leadId"]).to eq(2)
      expect(body["outputs"].first["agentName"]).to eq("A")
    end
  end

  describe "POST #send_email" do
    let(:lead) { double(id: 5) }

    it "returns 404 when lead missing" do
      allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(nil)

      post :send_email, params: { id: 1 }

      expect(response).to have_http_status(:not_found)
      body = JSON.parse(response.body)
      expect(body["errors"]).to include(/Lead not found or unauthorized/)
    end

    it "returns success when EmailSenderService succeeds" do
      allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(lead)
      allow(EmailSenderService).to receive(:send_email_for_lead).with(lead).and_return({ success: true, message: "Email sent" })

      post :send_email, params: { id: 1 }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["success"]).to be true
      expect(body["message"]).to eq("Email sent")
    end

    it "returns error when EmailSenderService fails" do
      allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(lead)
      allow(EmailSenderService).to receive(:send_email_for_lead).with(lead).and_return({ success: false, error: "Lead not ready" })

      post :send_email, params: { id: 1 }

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["success"]).to be false
      expect(body["error"]).to eq("Lead not ready")
    end

    it "handles exceptions raised by EmailSenderService" do
      allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(lead)
      allow(EmailSenderService).to receive(:send_email_for_lead).and_raise(StandardError, "Network error")

      post :send_email, params: { id: 1 }

      expect(response).to have_http_status(:internal_server_error)
      body = JSON.parse(response.body)
      expect(body["success"]).to be false
      expect(body["error"]).to eq("Network error")
    end
  end

  describe "PATCH #update_agent_output" do
    let(:lead) { double(id: 4, agent_outputs: double(find_by: nil)) }

    it "returns 404 when lead missing" do
      allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(nil)

      patch :update_agent_output, params: { id: 1 }

      expect(response).to have_http_status(:not_found)
    end

    it "requires agentName param" do
      allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(lead)

      patch :update_agent_output, params: { id: 1 }

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["errors"]).to include(/Agent name is required/)
    end

    it "rejects unsupported agent names" do
      allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(lead)

      patch :update_agent_output, params: { id: 1, agentName: "UNKNOWN" }

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["errors"]).to include(/Only WRITER, SEARCH, and DESIGN agent outputs can be updated/)
    end

    it "returns not found when agent output missing" do
      ao_double = double
      lead_with_empty = double(agent_outputs: double(find_by: nil))
      allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(lead_with_empty)

      patch :update_agent_output, params: { id: 1, agentName: AgentConstants::AGENT_WRITER }

      expect(response).to have_http_status(:not_found)
    end

    context "when updating WRITER" do
      it "requires content and updates successfully" do
        ao = double(agent_name: AgentConstants::AGENT_WRITER, status: "completed", output_data: {}, error_message: nil, created_at: Time.now, updated_at: Time.now)
        outputs = double(find_by: ao)
        lead_with_ao = double(agent_outputs: outputs)
        allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(lead_with_ao)
        allow(AgentOutputSerializer).to receive(:serialize).with(ao).and_return({
          "agentName" => "WRITER", "status" => "completed", "outputData" => { "email" => "hi" }
        })

        expect(ao).to receive(:output_data).and_return({})
        expect(ao).to receive(:update!).with(output_data: hash_including(:email)).and_return(true)

        patch :update_agent_output, params: { id: 1, agentName: AgentConstants::AGENT_WRITER, content: "hi" }

        expect(response).to have_http_status(:ok)
      end

      it "accepts email param as alternative to content" do
        ao = double(agent_name: AgentConstants::AGENT_WRITER, status: "completed", output_data: {}, error_message: nil, created_at: Time.now, updated_at: Time.now)
        outputs = double(find_by: ao)
        lead_with_ao = double(agent_outputs: outputs)
        allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(lead_with_ao)
        allow(AgentOutputSerializer).to receive(:serialize).with(ao).and_return({
          "agentName" => "WRITER", "status" => "completed", "outputData" => { "email" => "email-content" }
        })

        expect(ao).to receive(:output_data).and_return({})
        expect(ao).to receive(:update!).with(output_data: hash_including(email: "email-content")).and_return(true)

        patch :update_agent_output, params: { id: 1, agentName: AgentConstants::AGENT_WRITER, email: "email-content" }

        expect(response).to have_http_status(:ok)
      end

      it "returns unprocessable when content missing for WRITER" do
        ao = double(agent_name: AgentConstants::AGENT_WRITER, status: "ok", output_data: {}, updated_at: Time.now)
        outputs = double(find_by: ao)
        lead_with_ao = double(agent_outputs: outputs)
        allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(lead_with_ao)

        patch :update_agent_output, params: { id: 1, agentName: AgentConstants::AGENT_WRITER }

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["errors"]).to include(/Email content is required/)
      end
    end

    context "when updating DESIGN" do
      it "requires content and updates with formatted_email" do
        ao = double(agent_name: AgentConstants::AGENT_DESIGN, status: "completed", output_data: {}, error_message: nil, created_at: Time.now, updated_at: Time.now)
        outputs = double(find_by: ao)
        lead_with_ao = double(agent_outputs: outputs)
        allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(lead_with_ao)
        allow(AgentOutputSerializer).to receive(:serialize).with(ao).and_return({
          "agentName" => "DESIGN", "status" => "completed", "outputData" => { "formatted_email" => "hi" }
        })

        expect(ao).to receive(:output_data).and_return({})
        expect(ao).to receive(:update!).with(output_data: hash_including(:formatted_email)).and_return(true)

        patch :update_agent_output, params: { id: 1, agentName: AgentConstants::AGENT_DESIGN, content: "hi" }

        expect(response).to have_http_status(:ok)
      end

      it "accepts email param as alternative to content" do
        ao = double(agent_name: AgentConstants::AGENT_DESIGN, status: "completed", output_data: {}, error_message: nil, created_at: Time.now, updated_at: Time.now)
        outputs = double(find_by: ao)
        lead_with_ao = double(agent_outputs: outputs)
        allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(lead_with_ao)
        allow(AgentOutputSerializer).to receive(:serialize).with(ao).and_return({
          "agentName" => "DESIGN", "status" => "completed", "outputData" => { "email" => "email-content", "formatted_email" => "email-content" }
        })

        expect(ao).to receive(:output_data).and_return({})
        expect(ao).to receive(:update!).with(output_data: hash_including(email: "email-content", formatted_email: "email-content")).and_return(true)

        patch :update_agent_output, params: { id: 1, agentName: AgentConstants::AGENT_DESIGN, email: "email-content" }

        expect(response).to have_http_status(:ok)
      end

      it "accepts formatted_email param as alternative to content" do
        ao = double(agent_name: AgentConstants::AGENT_DESIGN, status: "completed", output_data: {}, error_message: nil, created_at: Time.now, updated_at: Time.now)
        outputs = double(find_by: ao)
        lead_with_ao = double(agent_outputs: outputs)
        allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(lead_with_ao)
        allow(AgentOutputSerializer).to receive(:serialize).with(ao).and_return({
          "agentName" => "DESIGN", "status" => "completed", "outputData" => { "email" => "formatted-content", "formatted_email" => "formatted-content" }
        })

        expect(ao).to receive(:output_data).and_return({})
        expect(ao).to receive(:update!).with(output_data: hash_including(email: "formatted-content", formatted_email: "formatted-content")).and_return(true)

        patch :update_agent_output, params: { id: 1, agentName: AgentConstants::AGENT_DESIGN, formatted_email: "formatted-content" }

        expect(response).to have_http_status(:ok)
      end

      it "returns unprocessable when content missing for DESIGN" do
        ao = double(agent_name: AgentConstants::AGENT_DESIGN, status: "ok", output_data: {}, updated_at: Time.now)
        outputs = double(find_by: ao)
        lead_with_ao = double(agent_outputs: outputs)
        allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(lead_with_ao)

        patch :update_agent_output, params: { id: 1, agentName: AgentConstants::AGENT_DESIGN }

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["errors"]).to include(/Email content is required/)
      end
    end

    context "when updating SEARCH" do
      it "requires updatedData and updates successfully" do
        ao = double(agent_name: AgentConstants::AGENT_SEARCH, status: "completed", output_data: {}, error_message: nil, created_at: Time.now, updated_at: Time.now)
        outputs = double(find_by: ao)
        lead_with_ao = double(agent_outputs: outputs)
        allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(lead_with_ao)
        allow(AgentOutputSerializer).to receive(:serialize).with(ao).and_return({
          "agentName" => "SEARCH", "status" => "completed", "outputData" => { "sources" => [] }
        })
        expect(ao).to receive(:update!).with(output_data: kind_of(ActionController::Parameters)).and_return(true)

        patch :update_agent_output, params: { id: 1, agentName: AgentConstants::AGENT_SEARCH, updatedData: { foo: "bar" } }

        expect(response).to have_http_status(:ok)
      end

      it "accepts updated_data (snake_case) as alternative to updatedData" do
        ao = double(agent_name: AgentConstants::AGENT_SEARCH, status: "completed", output_data: {}, error_message: nil, created_at: Time.now, updated_at: Time.now)
        outputs = double(find_by: ao)
        lead_with_ao = double(agent_outputs: outputs)
        allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(lead_with_ao)
        allow(AgentOutputSerializer).to receive(:serialize).with(ao).and_return({
          "agentName" => "SEARCH", "status" => "completed", "outputData" => { "baz" => "qux" }
        })
        expect(ao).to receive(:update!).with(output_data: kind_of(ActionController::Parameters)).and_return(true)

        patch :update_agent_output, params: { id: 1, agentName: AgentConstants::AGENT_SEARCH, updated_data: { baz: "qux" } }

        expect(response).to have_http_status(:ok)
      end

      it "returns unprocessable when updatedData missing for SEARCH" do
        ao = double(agent_name: AgentConstants::AGENT_SEARCH, status: "ok", output_data: {}, updated_at: Time.now)
        outputs = double(find_by: ao)
        lead_with_ao = double(agent_outputs: outputs)
        allow(Lead).to receive_message_chain(:includes, :joins, :where, :find_by).and_return(lead_with_ao)

        patch :update_agent_output, params: { id: 1, agentName: AgentConstants::AGENT_SEARCH }

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["errors"]).to include(/Updated data is required for SEARCH agent/)
      end
    end
  end
end
