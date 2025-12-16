require "rails_helper"

RSpec.describe LeadAgentService, type: :service do
  describe ".run_agents_for_lead" do
    it "is removed and raises (single-engine LeadRuns)" do
      user = create(:user)
      campaign = create(:campaign, user: user)
      lead = create(:lead, campaign: campaign)

      expect {
        described_class.run_agents_for_lead(lead, campaign, user)
      }.to raise_error(NotImplementedError, /legacy pipeline has been removed/i)
    end
  end
end

