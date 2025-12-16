require "rails_helper"

RSpec.describe "StageManager freeze", type: :model do
  it "ensures StageManager constant is removed" do
    expect(defined?(LeadAgentService::StageManager)).to be_nil
  end

  it "ensures no StageManager identifiers exist in app code" do
    patterns = [
      /LeadAgentService::StageManager\b/,
      /\bstage_manager\b/i,
      /\bstage_manager_facade\b/i,
      /\bstage_manager_deprecation\b/i,
      /\badvance_stage\b/,
      /\bdetermine_available_actions\b/,
      /\bupdate_lead_quality\b/
    ]

    violations = []

    Rails.root.glob("app/**/*.rb").each do |path|
      content = File.read(path)
      if patterns.any? { |pat| content.match?(pat) }
        violations << path.to_s
      end
    end

    expect(violations).to eq([])
  end
end
