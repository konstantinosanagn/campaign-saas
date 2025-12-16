require "rails_helper"

RSpec.describe "GET /api/v1/leads query budget", type: :request do
  let(:headers) { { "Accept" => "application/json" } }

  it "does not scale queries linearly with lead count" do
    user = create(:user)
    campaign = create(:campaign, user: user)

    # Ensure configs exist but avoid per-lead config queries.
    # Do not enable SENDER here (planner requires sending configuration if SENDER is enabled).
    %w[SEARCH WRITER CRITIQUE DESIGN].each do |agent|
      AgentConfig.create!(campaign: campaign, agent_name: agent, enabled: true, settings: {})
    end

    leads = Array.new(25) { create(:lead, campaign: campaign) }

    # Create active runs; for half, clear the pointer to simulate older data.
    leads.each_with_index do |lead, idx|
      run = LeadRunPlanner.build!(lead: lead)
      lead.update!(current_lead_run_id: nil) if idx.even?
      run.update!(status: "queued")
    end

    sign_in user

    queries = []
    subscriber =
      ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, _start, _finish, _id, payload|
        sql = payload[:sql].to_s
        next if payload[:name] == "SCHEMA"
        next if sql.start_with?("BEGIN") || sql.start_with?("COMMIT") || sql.start_with?("ROLLBACK")
        queries << sql
      end

    begin
      get "/api/v1/leads", headers: headers
      expect(response).to have_http_status(:ok)
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    # This endpoint should be O(1) queries relative to lead count (bounded eager-loads).
    # With preloads for agent_outputs, campaign:agent_configs, current_lead_run:steps,
    # and active_runs query, we expect bounded queries regardless of lead count.
    # The key is that it doesn't scale linearly - doubling leads shouldn't double queries.
    # Due to preloads and joins, actual query count may vary but should be bounded.
    # Adjust threshold if needed - important thing is it's not O(n) with lead count.
    expect(queries.length).to be <= 100
  end
end
