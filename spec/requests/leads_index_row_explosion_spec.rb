require "rails_helper"

RSpec.describe "GET /api/v1/leads row explosion prevention", type: :request do
  let(:headers) { { "Accept" => "application/json" } }

  it "uses preload (separate queries) instead of includes (cartesian join) to prevent row explosion" do
    user = create(:user)
    campaign = create(:campaign, user: user)

    # Create configs
    %w[SEARCH WRITER CRITIQUE DESIGN].each do |agent|
      AgentConfig.create!(campaign: campaign, agent_name: agent, enabled: true, settings: {})
    end

    # Create leads with many outputs, steps, and configs to test row explosion
    leads = Array.new(5) { create(:lead, campaign: campaign) }

    leads.each do |lead|
      # Create multiple agent outputs per lead
      10.times do |i|
        create(:agent_output, lead: lead, agent_name: "SEARCH", status: "completed", created_at: i.hours.ago)
      end

      # Create a run with many steps
      # LeadRunPlanner.build! already creates steps, so we'll add additional steps with higher positions
      run = LeadRunPlanner.build!(lead: lead)
      max_position = run.steps.maximum(:position) || 0
      5.times do |i|
        LeadRunStep.create!(
          lead_run: run,
          position: max_position + i + 1,
          agent_name: "WRITER",
          status: "completed",
          meta: {}
        )
      end
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

    # With preload, we should see multiple separate queries (one for leads, one for outputs, one for configs, etc.)
    # With includes + join, we'd see one massive cartesian join query
    # Assert we have multiple queries (indicating preload is working)
    expect(queries.length).to be > 5, "Expected multiple separate queries (preload), but got #{queries.length}. This suggests a cartesian join may have been reintroduced."

    # Focus on the main lead query (the one that used to explode with includes + join)
    # Find the SELECT query for leads table
    lead_queries = queries.select { |q| q.match?(/\bSELECT.*FROM.*leads\b/i) }
    expect(lead_queries.length).to be > 0, "Expected at least one query selecting from leads table"

    # The main lead query should not be a mega-join (cartesian explosion)
    # With preload, the lead query should have minimal joins (just the campaign join for authorization)
    lead_query_join_counts = lead_queries.map { |q| q.scan(/\bJOIN\b/i).length }
    max_lead_joins = lead_query_join_counts.max || 0

    # The lead query should only have the campaign join (for authorization), not multiple joins
    # that would cause row explosion (e.g., joining outputs, steps, configs all at once)
    expect(max_lead_joins).to be <= 1, "Found a lead query with #{max_lead_joins} JOINs. This suggests a cartesian join (row explosion) may have been reintroduced. Preload should use separate queries, with the lead query only joining campaigns for authorization."
  end
end
