require "rails_helper"

RSpec.describe LeadRun, type: :model do
  it { is_expected.to belong_to(:lead) }
  it { is_expected.to belong_to(:campaign) }
  it { is_expected.to have_many(:steps).class_name("LeadRunStep").dependent(:destroy) }

  it { is_expected.to validate_presence_of(:status) }

  describe "scopes" do
    it "defines active and terminal scopes" do
      expect(described_class).to respond_to(:active)
      expect(described_class).to respond_to(:terminal)
    end
  end

  describe "min_score validation" do
    let(:lead) { create(:lead) }
    let(:campaign) { lead.campaign }

    it "allows min_score = 10" do
      run = build(:lead_run, lead: lead, campaign: campaign, min_score: 10)
      expect(run).to be_valid
    end

    it "allows min_score = 0" do
      run = build(:lead_run, lead: lead, campaign: campaign, min_score: 0)
      expect(run).to be_valid
    end

    it "rejects min_score = 11" do
      run = build(:lead_run, lead: lead, campaign: campaign, min_score: 11)
      expect(run).not_to be_valid
      expect(run.errors[:min_score]).to be_present
    end

    it "rejects min_score = -1" do
      run = build(:lead_run, lead: lead, campaign: campaign, min_score: -1)
      expect(run).not_to be_valid
      expect(run.errors[:min_score]).to be_present
    end

    it "rejects non-integer min_score" do
      run = build(:lead_run, lead: lead, campaign: campaign, min_score: 5.5)
      expect(run).not_to be_valid
      expect(run.errors[:min_score]).to be_present
    end
  end
end
