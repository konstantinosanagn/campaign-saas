require 'rails_helper'

RSpec.describe Lead, type: :model do
  describe 'associations' do
    it { should belong_to(:campaign) }
    it { should have_many(:agent_outputs).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:company) }

    it { should allow_value('test@example.com').for(:email) }
    it { should allow_value('user.name+tag@domain.co.uk').for(:email) }
    it { should_not allow_value('invalid-email').for(:email) }
    it { should_not allow_value('@example.com').for(:email) }
    it { should_not allow_value('test@').for(:email) }
  end

  describe 'creation' do
    let(:user) { create(:user) }
    let(:campaign) { create(:campaign, user: user) }

    it 'creates a valid lead' do
      lead = build(:lead, campaign: campaign)
      expect(lead).to be_valid
      expect(lead.save).to be true
    end

    it 'requires a name' do
      lead = build(:lead, campaign: campaign, name: nil)
      expect(lead).not_to be_valid
      expect(lead.errors[:name]).to be_present
    end

    it 'requires an email' do
      lead = build(:lead, campaign: campaign, email: nil)
      expect(lead).not_to be_valid
      expect(lead.errors[:email]).to be_present
    end

    it 'requires a title' do
      lead = build(:lead, campaign: campaign, title: nil)
      expect(lead).not_to be_valid
      expect(lead.errors[:title]).to be_present
    end

    it 'requires a company' do
      lead = build(:lead, campaign: campaign, company: nil)
      expect(lead).not_to be_valid
      expect(lead.errors[:company]).to be_present
    end

    it 'requires a valid email format' do
      lead = build(:lead, campaign: campaign, email: 'invalid-email')
      expect(lead).not_to be_valid
      expect(lead.errors[:email]).to be_present
    end

    it 'requires a campaign' do
      lead = build(:lead, campaign: nil)
      expect(lead).not_to be_valid
      expect(lead.errors[:campaign]).to be_present
    end

    it 'has default stage value' do
      lead = create(:lead, campaign: campaign)
      expect(lead.stage).to eq('queued')
    end

    it 'has default quality value' do
      lead = create(:lead, campaign: campaign)
      expect(lead.quality).to eq('-')
    end
  end

  describe 'before_save callback' do
    let(:user) { create(:user) }
    let(:campaign) { create(:campaign, user: user) }

    it 'sets default website from email when website is empty' do
      lead = create(:lead_without_website, campaign: campaign)
      expect(lead.website).to eq('testcompany.com')
    end

    it 'sets default website from email when website is blank' do
      lead = build(:lead, campaign: campaign, email: 'user@example.com', website: '   ')
      lead.save
      expect(lead.website).to eq('example.com')
    end

    it 'does not override existing website' do
      lead = create(:lead, campaign: campaign, email: 'user@example.com', website: 'custom.com')
      expect(lead.website).to eq('custom.com')
    end
  end

  describe 'camelCase API compatibility' do
    let(:user) { create(:user) }
    let(:campaign) { create(:campaign, user: user) }
    let(:lead) { create(:lead, campaign: campaign) }

    it 'returns camelCase when serialized' do
      json = LeadSerializer.serialize(lead)
      expect(json).to have_key('campaignId')
      expect(json).not_to have_key('campaign_id')
      expect(json['campaignId']).to eq(campaign.id)
    end
  end

  describe 'agent_outputs association' do
    let(:user) { create(:user) }
    let(:campaign) { create(:campaign, user: user) }
    let(:lead) { create(:lead, campaign: campaign) }

    it 'can have multiple agent outputs' do
      search_output = create(:agent_output, lead: lead, agent_name: 'SEARCH')
      writer_output = create(:agent_output, lead: lead, agent_name: 'WRITER')

      expect(lead.agent_outputs.count).to eq(2)
      expect(lead.agent_outputs).to include(search_output, writer_output)
    end

    it 'destroys associated agent outputs when lead is destroyed' do
      output = create(:agent_output, lead: lead)
      output_id = output.id

      lead.destroy

      expect(AgentOutput.find_by(id: output_id)).to be_nil
    end
  end
end
