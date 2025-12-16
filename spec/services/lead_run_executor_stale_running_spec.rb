require "rails_helper"

RSpec.describe "LeadRunExecutor stale running recovery" do
  it "fails a stale running step and marks the run failed" do
    user = create(:user, llm_api_key: "dummy", tavily_api_key: "dummy")
    campaign = create(:campaign, user: user)
    lead = create(:lead, campaign: campaign)

    AgentConfig.create!(campaign: campaign, agent_name: "SEARCH", enabled: true, settings: {})

    run = LeadRunPlanner.build!(lead: lead)
    step = run.steps.order(:position).first

    run.update!(status: "running", started_at: 2.hours.ago)
    step.update!(status: "running", step_started_at: 2.hours.ago)
    lead.update!(current_lead_run: run)

    result = LeadRunExecutor.run_next!(lead_run_id: run.id)
    expect(result[:result_type]).to eq(:failed_timeout_recovery)

    step.reload
    run.reload
    lead.reload

    expect(step.status).to eq("failed")
    expect(run.status).to eq("failed")
    expect(lead.current_lead_run_id).to be_nil

    output = AgentOutput.find_by(lead_run_step_id: step.id)
    expect(output).to be_present
    expect(output.status).to eq("failed")
    expect((output.output_data || {})["error"]).to eq("timeout")
  end
end
