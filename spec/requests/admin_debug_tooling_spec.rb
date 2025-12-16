require "rails_helper"

RSpec.describe "Admin debug tooling", type: :request do
  let(:headers) { { "Accept" => "application/json" } }

  around do |example|
    old = ENV["ADMIN_EMAILS"]
    ENV["ADMIN_EMAILS"] = admin_emails
    example.run
  ensure
    ENV["ADMIN_EMAILS"] = old
  end

  let(:admin_user) { create(:user, email: "admin1@example.com") }
  let(:non_admin_user) { create(:user, email: "user1@example.com") }
  let(:admin_emails) { "" }

  it "blocks non-admin users (404)" do
    sign_in non_admin_user

    run = LeadRun.create!(lead: create(:lead, campaign: create(:campaign, user: non_admin_user)),
                          campaign: Campaign.last,
                          status: "queued",
                          plan: {},
                          config_snapshot: {})

    get "/admin/lead_runs/#{run.id}", headers: headers
    expect(response).to have_http_status(:not_found)
  end

  context "when admin" do
    let(:admin_emails) { admin_user.email }

    it "allows access (200) and redacts secrets" do
      campaign = create(:campaign, user: admin_user)
      lead = create(:lead, campaign: campaign)

      run = LeadRun.create!(
        lead: lead,
        campaign: campaign,
        status: "queued",
        plan: {},
        config_snapshot: { "llm_api_key" => "AIzaSHOULD_NOT_APPEAR", "authorization" => "Bearer NOPE" }
      )
      step = LeadRunStep.create!(lead_run: run, position: 1, agent_name: "SEARCH", status: "queued", meta: { "access_token" => "Bearer NOPE" })
      AgentOutput.create!(
        lead: lead,
        lead_run: run,
        lead_run_step: step,
        agent_name: "SEARCH",
        status: "completed",
        output_data: { "refresh_token" => "tvly-should-not-appear", "body" => "Bearer SHOULD_NOT_APPEAR" }
      )

      sign_in admin_user

      get "/admin/lead_runs/#{run.id}", headers: headers
      expect(response).to have_http_status(:ok)
      body = response.body
      expect(body).not_to include("AIza")
      expect(body).not_to include("tvly-")
      expect(body).not_to include("Bearer")
      expect(body).not_to include("refresh_token")

      get "/admin/agent_outputs?lead_run_id=#{run.id}&limit=10", headers: headers
      expect(response).to have_http_status(:ok)
      body = response.body
      expect(body).not_to include("AIza")
      expect(body).not_to include("tvly-")
      expect(body).not_to include("Bearer")
      expect(body).not_to include("refresh_token")
    end
  end
end
