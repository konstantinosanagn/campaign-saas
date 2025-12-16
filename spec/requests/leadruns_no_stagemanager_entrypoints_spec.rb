require "rails_helper"

RSpec.describe "LeadRuns: no StageManager calls on key entrypoints", type: :request do
  let(:headers) { { "Accept" => "application/json" } }

  it "POST /api/v1/leads/:id/run_agents works without StageManager constants" do
    user = create(:user)
    campaign = create(:campaign, user: user)
    lead = create(:lead, campaign: campaign)

    sign_in user

    post "/api/v1/leads/#{lead.id}/run_agents", params: { async: true }, headers: headers
    expect(response).to have_http_status(:accepted)
    expect(defined?(LeadAgentService::StageManager)).to be_nil
  end

  it "POST /api/v1/leads/:id/resume_run works without StageManager constants" do
    user = create(:user)
    campaign = create(:campaign, user: user)
    lead = create(:lead, campaign: campaign)

    sign_in user

    post "/api/v1/leads/#{lead.id}/resume_run", headers: headers
    # If no run exists yet, controller returns a conservative noop.
    expect(response).to have_http_status(:ok)
    expect(defined?(LeadAgentService::StageManager)).to be_nil
  end
end
