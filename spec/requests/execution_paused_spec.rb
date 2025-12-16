require "rails_helper"

RSpec.describe "Execution pause switch", type: :request do
  let(:headers) { { "Accept" => "application/json" } }

  around do |example|
    old = ENV["AGENT_EXECUTION_PAUSED"]
    ENV["AGENT_EXECUTION_PAUSED"] = "true"
    example.run
  ensure
    ENV["AGENT_EXECUTION_PAUSED"] = old
  end

  it "blocks enqueueing run_agents but still plans a run" do
    user = create(:user)
    campaign = create(:campaign, user: user)
    lead = create(:lead, campaign: campaign)

    sign_in user

    expect {
      post "/api/v1/leads/#{lead.id}/run_agents", params: { async: true }, headers: headers
    }.not_to have_enqueued_job(AgentExecutionJob)

    expect(response).to have_http_status(:service_unavailable)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("failed")
    expect(json["error"]).to eq("execution_paused")

    lead.reload
    expect(lead.current_lead_run_id).to be_present
  end

  it "does not mutate step status when paused (no queued->running)" do
    user = create(:user)
    campaign = create(:campaign, user: user)

    # Enable the pipeline so the planner creates multiple queued steps.
    %w[SEARCH WRITER CRITIQUE DESIGN].each do |agent|
      AgentConfig.create!(campaign: campaign, agent_name: agent, enabled: true, settings: {})
    end

    lead = create(:lead, campaign: campaign)
    sign_in user

    post "/api/v1/leads/#{lead.id}/run_agents", params: { async: true }, headers: headers
    expect(response).to have_http_status(:service_unavailable)

    run = lead.reload.current_lead_run
    expect(run).to be_present

    statuses = run.steps.order(:position).pluck(:status)
    expect(statuses).to all(eq("queued"))
  end

  it "resume_run does not mutate step status when paused" do
    user = create(:user)
    campaign = create(:campaign, user: user)
    lead = create(:lead, campaign: campaign)

    run = LeadRun.create!(lead: lead, campaign: campaign, status: "queued", plan: {}, config_snapshot: {})
    step = LeadRunStep.create!(lead_run: run, position: 10, agent_name: "SEARCH", status: "queued", meta: {})
    lead.update!(current_lead_run: run)

    sign_in user

    expect {
      post "/api/v1/leads/#{lead.id}/resume_run", headers: headers
    }.not_to have_enqueued_job(AgentExecutionJob)

    expect(response).to have_http_status(:service_unavailable)
    step.reload
    expect(step.status).to eq("queued")
  end
end
