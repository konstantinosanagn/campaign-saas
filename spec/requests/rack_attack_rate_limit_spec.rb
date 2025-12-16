require "rails_helper"

RSpec.describe "Rack::Attack rate limiting", type: :request do
  let(:headers) { { "Accept" => "application/json" } }

  let(:user_a) { create(:user) }
  let(:user_b) { create(:user) }

  let!(:campaign_a) { create(:campaign, user: user_a) }
  let!(:campaign_b) { create(:campaign, user: user_b) }
  let!(:lead_a) { create(:lead, campaign: campaign_a) }
  let!(:lead_b) { create(:lead, campaign: campaign_b) }

  before do
    # Ensure a clean slate so this spec doesn't get polluted by other request specs.
    Rack::Attack.cache.store.clear if Rack::Attack.cache.store.respond_to?(:clear)
  end

  it "rate-limits one user without immediately rate-limiting another user" do
    sign_in user_a

    # Trip the throttle for user A.
    10.times do
      post "/api/v1/leads/#{lead_a.id}/run_agents", params: { async: true }, headers: headers
      expect(response).not_to have_http_status(:too_many_requests)
    end

    post "/api/v1/leads/#{lead_a.id}/run_agents", params: { async: true }, headers: headers
    expect(response).to have_http_status(:too_many_requests)

    sign_out user_a

    # User B should not be throttled if the discriminator is truly user-scoped.
    sign_in user_b
    post "/api/v1/leads/#{lead_b.id}/run_agents", params: { async: true }, headers: headers
    expect(response).not_to have_http_status(:too_many_requests)
  end

  it "rate-limits resume_run per user (A throttled does not throttle B)" do
    # Ensure each lead has an active run so resume_run does real work.
    run_a = LeadRun.create!(lead: lead_a, campaign: campaign_a, status: "queued", plan: {}, config_snapshot: {})
    LeadRunStep.create!(lead_run: run_a, position: 1, agent_name: "SEARCH", status: "queued", meta: {})
    run_b = LeadRun.create!(lead: lead_b, campaign: campaign_b, status: "queued", plan: {}, config_snapshot: {})
    LeadRunStep.create!(lead_run: run_b, position: 1, agent_name: "SEARCH", status: "queued", meta: {})

    sign_in user_a

    5.times do
      post "/api/v1/leads/#{lead_a.id}/resume_run", headers: headers
      expect(response).not_to have_http_status(:too_many_requests)
    end

    post "/api/v1/leads/#{lead_a.id}/resume_run", headers: headers
    expect(response).to have_http_status(:too_many_requests)

    sign_out user_a

    sign_in user_b
    post "/api/v1/leads/#{lead_b.id}/resume_run", headers: headers
    expect(response).not_to have_http_status(:too_many_requests)
  end
end
