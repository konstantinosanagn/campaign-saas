require "rails_helper"

RSpec.describe "LeadRuns entrypoints", type: :request do
  let(:headers) { { "Accept" => "application/json" } }

  it "GET /api/v1/leads does not invoke StageManagerFacade (tripwire)" do
    user = create(:user)
    campaign = create(:campaign, user: user)
    lead = create(:lead, campaign: campaign)

    sign_in user

    get "/api/v1/leads", headers: headers
    expect(response).to have_http_status(:ok)
    expect(defined?(LeadAgentService::StageManager)).to be_nil
  end

  it "GET /api/v1/leads/:id/available_actions works without StageManager constants" do
    user = create(:user)
    campaign = create(:campaign, user: user)
    lead = create(:lead, campaign: campaign)

    sign_in user

    get "/api/v1/leads/#{lead.id}/available_actions", headers: headers
    expect(response).to have_http_status(:ok)
    expect(defined?(LeadAgentService::StageManager)).to be_nil
  end
end
