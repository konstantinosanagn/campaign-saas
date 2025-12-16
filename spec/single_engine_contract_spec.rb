require "rails_helper"

RSpec.describe "Single engine (LeadRuns-only) contract", type: :request do
  it "has no LeadRuns engine toggle remnants" do
    patterns = [
      /\bLEAD_RUNS_ENABLED\b/,
      /\bLeadRuns\.enabled\?\b/
    ]

    violations = []

    Rails.root.glob("{app,config}/**/*.rb").each do |path|
      content = File.read(path)
      violations << path.to_s if patterns.any? { |pat| content.match?(pat) }
    end

    expect(violations).to eq([])
  end

  it "has no StageManager constant or class" do
    # Check that StageManager is not defined as a constant
    expect(defined?(StageManager)).to be_nil, "StageManager constant should not exist. LeadRuns is the only execution engine."

    # Also check source files for StageManager class/module definitions
    violations = []
    Rails.root.glob("{app,lib}/**/*.rb").each do |path|
      content = File.read(path)
      # Look for class StageManager or module StageManager definitions
      if content.match?(/\b(class|module)\s+StageManager\b/)
        violations << path.to_s
      end
    end

    expect(violations).to eq([]), "Found StageManager class/module definitions in: #{violations.join(', ')}. StageManager has been deprecated in favor of LeadRuns."
  end

  it "available_actions always returns LeadRuns-shaped payload" do
    user = create(:user)
    campaign = create(:campaign, user: user)
    lead = create(:lead, campaign: campaign)

    sign_in user

    get "/api/v1/leads/#{lead.id}/available_actions", headers: { "Accept" => "application/json" }
    expect(response).to have_http_status(:ok)

    json = JSON.parse(response.body)
    expect(json).to include(
      "run_id",
      "run_status",
      "running_step",
      "last_completed_step",
      "next_step",
      "rewrite_count",
      "can_send"
    )
    expect(json).not_to have_key("mode")
  end

  it "run_agents does not reference the legacy pipeline" do
    content = File.read(Rails.root.join("app/controllers/api/v1/leads_controller.rb"))
    expect(content).not_to match(/run_agents_for_lead/)
  end
end
