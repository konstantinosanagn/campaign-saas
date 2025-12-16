require "rails_helper"

RSpec.describe "Smoke: LeadRuns endpoints", type: :request do
  let(:headers) { { "Accept" => "application/json" } }

  it "hits run_agents, available_actions, and resume_run without legacy state machine" do
    user = create(:user, llm_api_key: "dummy", tavily_api_key: "dummy")
    campaign = create(:campaign, user: user)

    %w[SEARCH WRITER CRITIQUE DESIGN].each do |agent|
      AgentConfig.find_or_create_by!(campaign_id: campaign.id, agent_name: agent) do |cfg|
        cfg.enabled = true
        cfg.settings = {}
      end
    end

    lead = create(:lead, campaign: campaign, stage: "queued", quality: "-")

    # Create the run (plan) while SEARCH is enabled, then disable it.
    lead.ensure_active_run!

    sign_in user

    # Disable SEARCH after the run is planned to exercise auto-skip of disabled queued steps.
    AgentConfig.find_by!(campaign_id: campaign.id, agent_name: "SEARCH").update!(enabled: false)

    # available_actions => should skip SEARCH and surface WRITER as next runnable step
    get "/api/v1/leads/#{lead.id}/available_actions", headers: headers
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json["run_status"]).to be_present
    expect(json.dig("next_step", "agent_name")).to eq("WRITER")

    # run_agents (async) => allow agentName=WRITER (after skipping disabled steps), enqueue job
    expect {
      post "/api/v1/leads/#{lead.id}/run_agents", params: { async: true, agentName: "WRITER" }, headers: headers
    }.to have_enqueued_job(AgentExecutionJob)
    expect(response).to have_http_status(:accepted)

    # resume_run => should be safe and return a payload with resume info
    post "/api/v1/leads/#{lead.id}/resume_run", headers: headers
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json["resume"]).to be_present
  end
end
