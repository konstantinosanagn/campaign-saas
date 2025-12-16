require "rails_helper"

RSpec.describe LeadRuns::Resume do
  it "enqueues when running step is stale" do
    user = create(:user)
    campaign = create(:campaign, user: user)
    lead = create(:lead, campaign: campaign)

    run = LeadRun.create!(lead: lead, campaign: campaign, status: "running", plan: {}, config_snapshot: {}, started_at: 2.hours.ago)
    LeadRunStep.create!(lead_run: run, position: 10, agent_name: "SEARCH", status: "running", meta: {}, step_started_at: 2.hours.ago)
    lead.update!(current_lead_run: run)

    result = described_class.call(lead_run_id: run.id)
    expect(result[:enqueue]).to eq(true)
    expect(result[:reason]).to eq("stale_running")
  end

  it "does not enqueue when running step is not stale" do
    user = create(:user)
    campaign = create(:campaign, user: user)
    lead = create(:lead, campaign: campaign)

    run = LeadRun.create!(lead: lead, campaign: campaign, status: "running", plan: {}, config_snapshot: {}, started_at: 1.minute.ago)
    LeadRunStep.create!(lead_run: run, position: 10, agent_name: "SEARCH", status: "running", meta: {}, step_started_at: 1.minute.ago)
    lead.update!(current_lead_run: run)

    result = described_class.call(lead_run_id: run.id)
    expect(result[:enqueue]).to eq(false)
    expect(result[:reason]).to eq("already_running")
  end
end
