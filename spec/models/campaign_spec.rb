require 'rails_helper'

RSpec.describe Campaign, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:leads).dependent(:destroy) }
    it { should have_many(:agent_configs).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:title) }
  end

  describe 'creation' do
    let(:user) { create(:user) }

    it 'creates a valid campaign' do
      campaign = build(:campaign, user: user)
      expect(campaign).to be_valid
      expect(campaign.save).to be true
    end

    it 'requires a title' do
      campaign = build(:campaign, user: user, title: nil)
      expect(campaign).not_to be_valid
      expect(campaign.errors[:title]).to be_present
    end


    it 'requires a user' do
      campaign = build(:campaign, user: nil)
      expect(campaign).not_to be_valid
      expect(campaign.errors[:user]).to be_present
    end
  end

  describe 'shared_settings' do
    let(:user) { create(:user) }
    let(:campaign) { create(:campaign, user: user) }

    it 'returns default shared_settings when not set' do
      expect(campaign.shared_settings).to be_a(Hash)
      expect(campaign.shared_settings['brand_voice']).to be_a(Hash)
      expect(campaign.shared_settings['primary_goal']).to eq('book_call')
    end

    it 'returns camelCase in as_json' do
      json = campaign.as_json
      expect(json).to have_key('sharedSettings')
      expect(json['sharedSettings']).to be_a(Hash)
    end
  end

  describe 'leads association' do
    let(:user) { create(:user) }
    let(:campaign) { create(:campaign, user: user) }

    it 'can have multiple leads' do
      lead1 = create(:lead, campaign: campaign)
      lead2 = create(:lead, campaign: campaign)

      expect(campaign.leads.count).to eq(2)
      expect(campaign.leads).to include(lead1, lead2)
    end

    it 'destroys associated leads when campaign is destroyed' do
      lead = create(:lead, campaign: campaign)
      campaign_id = campaign.id
      lead_id = lead.id

      campaign.destroy

      expect(Lead.find_by(id: lead_id)).to be_nil
      expect(Campaign.find_by(id: campaign_id)).to be_nil
    end
  end

  describe 'agent_configs association' do
    let(:user) { create(:user) }
    let(:campaign) { create(:campaign, user: user) }

    it 'can have multiple agent configs' do
      search_config = create(:agent_config, campaign: campaign, agent_name: 'SEARCH')
      writer_config = create(:agent_config, campaign: campaign, agent_name: 'WRITER')

      expect(campaign.agent_configs.count).to eq(2)
      expect(campaign.agent_configs).to include(search_config, writer_config)
    end

    it 'destroys associated agent configs when campaign is destroyed' do
      config = create(:agent_config, campaign: campaign)
      config_id = config.id

      campaign.destroy

      expect(AgentConfig.find_by(id: config_id)).to be_nil
    end
  end

  describe 'shared_settings edge cases' do
    let(:user) { create(:user) }
    it 'falls back to defaults when stored value is nil or empty and provides helpers' do
      campaign = create(:campaign, user: user, shared_settings: { 'primary_goal' => 'generate_leads' })

      allow(campaign).to receive(:read_attribute).with(:shared_settings).and_return(nil)
      expect(campaign.shared_settings).to be_a(Hash)
      expect(campaign.primary_goal).to eq('book_call')
      expect(campaign.brand_voice).to include('tone' => 'professional')

      allow(campaign).to receive(:read_attribute).and_call_original
      campaign.update_column(:shared_settings, {})
      expect(campaign.read_attribute(:shared_settings)).to eq({})
      expect(campaign.shared_settings).to be_a(Hash)
      expect(campaign.primary_goal).to eq('book_call')
    end

    it 'respects persisted custom shared_settings' do
      custom = { 'brand_voice' => { 'tone' => 'casual' }, 'primary_goal' => 'book_call' }
      campaign = create(:campaign, user: user, shared_settings: custom)

      reloaded = Campaign.find(campaign.id)
      expect(reloaded.read_attribute(:shared_settings)).to eq(custom)
      expect(reloaded.shared_settings).to eq(custom)

      json = campaign.as_json
      expect(json).to have_key('sharedSettings')
      expect(json['sharedSettings']).to eq(custom)
      expect(json).not_to have_key('shared_settings')
    end
  end
end
