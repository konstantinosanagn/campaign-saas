require "rails_helper"

RSpec.describe "POST /api/v1/leads/:id/resume_run authorization", type: :request do
  let(:headers) { { "Accept" => "application/json" } }

  it "does not allow a user to resume another user's lead run (IDOR protection)" do
    user_a = create(:user)
    user_b = create(:user)

    campaign_a = create(:campaign, user: user_a)
    lead_a = create(:lead, campaign: campaign_a)

    run = LeadRun.create!(lead: lead_a, campaign: campaign_a, status: "queued", plan: {}, config_snapshot: {})
    LeadRunStep.create!(lead_run: run, position: 1, agent_name: "SEARCH", status: "queued", meta: {})

    sign_in user_b
    post "/api/v1/leads/#{lead_a.id}/resume_run", headers: headers
    expect(response).to have_http_status(:not_found)
  end
end
