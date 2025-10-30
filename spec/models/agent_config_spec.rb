require 'rails_helper'

RSpec.describe AgentConfig, type: :model do
  describe 'associations' do
    it { should belong_to(:campaign) }
  end

  describe 'validations' do
    let(:user) { create(:user) }
    let(:campaign) { create(:campaign, user: user) }

    it { should validate_presence_of(:campaign_id) }
    it { should validate_presence_of(:agent_name) }
    # Settings allows empty hash {} but not nil
    it 'requires settings to not be nil' do
      config = build(:agent_config, campaign: campaign, settings: nil)
      expect(config).not_to be_valid
      expect(config.errors[:settings]).to be_present
    end
    it { should validate_inclusion_of(:enabled).in_array([true, false]) }

    it 'validates agent_name inclusion' do
      valid_names = %w[SEARCH WRITER CRITIQUE]
      valid_names.each do |name|
        config = build(:agent_config, campaign: campaign, agent_name: name)
        expect(config).to be_valid
      end
    end

    it 'rejects invalid agent_name' do
      config = build(:agent_config, campaign: campaign, agent_name: 'INVALID')
      expect(config).not_to be_valid
      expect(config.errors[:agent_name]).to be_present
    end

    it 'requires settings' do
      config = build(:agent_config, campaign: campaign, settings: nil)
      expect(config).not_to be_valid
      expect(config.errors[:settings]).to be_present
    end
  end

  describe 'status query methods' do
    let(:user) { create(:user) }
    let(:campaign) { create(:campaign, user: user) }

    it 'returns true for enabled? when enabled is true' do
      config = create(:agent_config, campaign: campaign, enabled: true)
      expect(config.enabled?).to be true
      expect(config.disabled?).to be false
    end

    it 'returns true for disabled? when enabled is false' do
      config = create(:agent_config_disabled, campaign: campaign)
      expect(config.disabled?).to be true
      expect(config.enabled?).to be false
    end
  end

  describe 'settings accessor methods' do
    let(:user) { create(:user) }
    let(:campaign) { create(:campaign, user: user) }

    it 'gets setting value with string key' do
      config = create(:agent_config_writer, campaign: campaign)
      expect(config.get_setting('product_info')).to eq('AI-powered marketing automation tool')
    end

    it 'gets setting value with symbol key' do
      config = create(:agent_config_writer, campaign: campaign)
      expect(config.get_setting(:product_info)).to eq('AI-powered marketing automation tool')
    end

    it 'returns nil for non-existent setting' do
      config = create(:agent_config, campaign: campaign)
      expect(config.get_setting('nonexistent')).to be_nil
    end

    it 'sets setting value' do
      config = create(:agent_config, campaign: campaign)
      config.set_setting('product_info', 'New product info')
      expect(config.get_setting('product_info')).to eq('New product info')
      expect(config.settings['product_info']).to eq('New product info')
    end

    it 'preserves existing settings when setting new one' do
      config = create(:agent_config_writer, campaign: campaign)
      original_product_info = config.get_setting('product_info')
      config.set_setting('new_key', 'new_value')
      expect(config.get_setting('product_info')).to eq(original_product_info)
      expect(config.get_setting('new_key')).to eq('new_value')
    end
  end

  describe 'database constraints' do
    let(:user) { create(:user) }
    let(:campaign) { create(:campaign, user: user) }

    it 'prevents duplicate agent configs for the same campaign and agent' do
      create(:agent_config, campaign: campaign, agent_name: 'WRITER')
      duplicate = build(:agent_config, campaign: campaign, agent_name: 'WRITER')
      
      expect { duplicate.save! }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'allows different agent configs for the same campaign' do
      create(:agent_config, campaign: campaign, agent_name: 'SEARCH')
      writer_config = build(:agent_config, campaign: campaign, agent_name: 'WRITER')
      expect(writer_config).to be_valid
      expect(writer_config.save).to be true
    end

    it 'allows same agent config for different campaigns' do
      campaign2 = create(:campaign, user: user)
      create(:agent_config, campaign: campaign, agent_name: 'WRITER')
      config2 = build(:agent_config, campaign: campaign2, agent_name: 'WRITER')
      expect(config2).to be_valid
      expect(config2.save).to be true
    end

    it 'requires valid agent_name via database constraint' do
      config = build(:agent_config, campaign: campaign, agent_name: 'INVALID_AGENT')
      config.valid?
      expect(config.errors[:agent_name]).to be_present
    end
  end

  describe 'creation' do
    let(:user) { create(:user) }
    let(:campaign) { create(:campaign, user: user) }

    it 'creates a valid agent config' do
      config = build(:agent_config, campaign: campaign)
      expect(config).to be_valid
      expect(config.save).to be true
    end

    it 'has default enabled value of true' do
      config = AgentConfig.new(campaign: campaign, agent_name: 'SEARCH', settings: {})
      expect(config.enabled).to be true
    end

    it 'can store complex JSONB settings' do
      complex_settings = {
        'product_info' => 'Complex product description',
        'sender_company' => 'Company Name',
        'custom_field' => { 'nested' => 'value' }
      }
      config = create(:agent_config, campaign: campaign, settings: complex_settings)
      expect(config.settings).to eq(complex_settings)
      expect(config.get_setting('custom_field')['nested']).to eq('value')
    end
  end
end

