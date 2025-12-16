require "rails_helper"

RSpec.describe "LeadRuns claim-time settings snapshot" do
  it "snapshots settings into step.meta when claimed and keeps it stable" do
    user = create(:user, llm_api_key: "dummy", tavily_api_key: "dummy")
    campaign = create(:campaign, user: user, shared_settings: { "brand_voice" => { "tone" => "friendly" } })
    lead = create(:lead, campaign: campaign)

    # Create an enabled SEARCH config with some settings so we can observe the snapshot.
    AgentConfig.create!(campaign: campaign, agent_name: "SEARCH", enabled: true, settings: { "search_depth" => "deep" })
    AgentConfig.create!(campaign: campaign, agent_name: "WRITER", enabled: true, settings: { "product_info" => "X", "sender_company" => "Y" })

    run = LeadRunPlanner.build!(lead: lead)
    step = run.steps.order(:position).first
    expect(step.status).to eq("queued")

    # Claim once (do not execute) via private method
    executor = LeadRunExecutor.new(lead_run_id: run.id, requested_agent_name: step.agent_name)
    action = executor.send(:claim_or_prepare_action!)
    expect(action[:result_type]).to eq(:claimed)

    step.reload
    expect(step.status).to eq("running")
    snapshot1 = (step.meta || {})["settings_snapshot"]
    expect(snapshot1).to be_present
    expect(snapshot1).to include("search_depth" => "deep")

    # Simulate a retry by putting it back to queued but keeping meta.
    step.update!(status: "queued")

    executor2 = LeadRunExecutor.new(lead_run_id: run.id, requested_agent_name: step.agent_name)
    action2 = executor2.send(:claim_or_prepare_action!)
    expect(action2[:result_type]).to eq(:claimed)

    step.reload
    snapshot2 = (step.meta || {})["settings_snapshot"]
    expect(snapshot2).to eq(snapshot1)
  end
end
