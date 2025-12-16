require "rails_helper"

RSpec.describe "LeadRunExecutor pause behavior" do
  around do |example|
    old = ENV["AGENT_EXECUTION_PAUSED"]
    ENV["AGENT_EXECUTION_PAUSED"] = "true"
    example.run
  ensure
    ENV["AGENT_EXECUTION_PAUSED"] = old
  end

  it "returns early and does not claim/transition any step" do
    user = create(:user)
    campaign = create(:campaign, user: user)
    lead = create(:lead, campaign: campaign)

    AgentConfig.create!(campaign: campaign, agent_name: "SEARCH", enabled: true, settings: {})
    run = LeadRunPlanner.build!(lead: lead)
    step = run.steps.order(:position).first
    expect(step.status).to eq("queued")

    result = LeadRunExecutor.run_next!(lead_run_id: run.id)
    expect(result[:result_type]).to eq(:paused)

    step.reload
    run.reload
    expect(step.status).to eq("queued")
    expect(run.status).to eq("queued")
  end
end
