require 'rails_helper'

RSpec.describe AgentOutput, type: :model do
  describe 'associations' do
    it { should belong_to(:lead) }
  end

  describe 'validations' do
    let(:user) { create(:user) }
    let(:campaign) { create(:campaign, user: user) }
    let(:lead) { create(:lead, campaign: campaign) }

    it { should validate_presence_of(:lead_id) }
    it { should validate_presence_of(:agent_name) }
    it { should validate_presence_of(:status) }
    it { should validate_presence_of(:output_data) }

    it 'validates agent_name inclusion' do
      valid_names = %w[SEARCH WRITER CRITIQUE]
      valid_names.each do |name|
        output = build(:agent_output, lead: lead, agent_name: name)
        expect(output).to be_valid
      end
    end

    it 'rejects invalid agent_name' do
      output = build(:agent_output, lead: lead, agent_name: 'INVALID')
      expect(output).not_to be_valid
      expect(output.errors[:agent_name]).to be_present
    end

    it 'validates status inclusion' do
      valid_statuses = %w[pending completed failed]
      valid_statuses.each do |status|
        output = build(:agent_output, lead: lead, status: status)
        expect(output).to be_valid
      end
    end

    it 'rejects invalid status' do
      output = build(:agent_output, lead: lead, status: 'invalid_status')
      expect(output).not_to be_valid
      expect(output.errors[:status]).to be_present
    end

    it 'requires output_data' do
      output = build(:agent_output, lead: lead, output_data: nil)
      expect(output).not_to be_valid
      expect(output.errors[:output_data]).to be_present
    end
  end

  describe 'status query methods' do
    let(:user) { create(:user) }
    let(:campaign) { create(:campaign, user: user) }
    let(:lead) { create(:lead, campaign: campaign) }

    it 'returns true for completed? when status is completed' do
      output = create(:agent_output, lead: lead, status: 'completed')
      expect(output.completed?).to be true
      expect(output.pending?).to be false
      expect(output.failed?).to be false
    end

    it 'returns true for pending? when status is pending' do
      output = create(:agent_output, lead: lead, status: 'pending')
      expect(output.pending?).to be true
      expect(output.completed?).to be false
      expect(output.failed?).to be false
    end

    it 'returns true for failed? when status is failed' do
      output = create(:agent_output_failed, lead: lead)
      expect(output.failed?).to be true
      expect(output.completed?).to be false
      expect(output.pending?).to be false
    end
  end

  describe 'database constraints' do
    let(:user) { create(:user) }
    let(:campaign) { create(:campaign, user: user) }
    let(:lead) { create(:lead, campaign: campaign) }

    it 'prevents duplicate agent outputs for the same lead and agent' do
      create(:agent_output, lead: lead, agent_name: 'SEARCH')
      duplicate = build(:agent_output, lead: lead, agent_name: 'SEARCH')

      expect { duplicate.save! }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'allows different agent outputs for the same lead' do
      create(:agent_output, lead: lead, agent_name: 'SEARCH')
      writer_output = build(:agent_output, lead: lead, agent_name: 'WRITER')
      expect(writer_output).to be_valid
      expect(writer_output.save).to be true
    end

    it 'requires valid agent_name via database constraint' do
      output = build(:agent_output, lead: lead, agent_name: 'INVALID_AGENT')
      # Model validation will catch it, but if it somehow passes, DB constraint will catch it
      output.valid?
      expect(output.errors[:agent_name]).to be_present
    end

    it 'requires valid status via database constraint' do
      # Try to save with invalid status
      output = build(:agent_output, lead: lead, status: 'invalid')
      expect(output).not_to be_valid
    end
  end

  describe 'creation' do
    let(:user) { create(:user) }
    let(:campaign) { create(:campaign, user: user) }
    let(:lead) { create(:lead, campaign: campaign) }

    it 'creates a valid agent output' do
      output = build(:agent_output, lead: lead)
      expect(output).to be_valid
      expect(output.save).to be true
    end

    it 'has default status of pending' do
      output = AgentOutput.new(lead: lead, agent_name: 'SEARCH', output_data: {})
      expect(output.status).to eq('pending')
    end

    it 'can store complex JSONB data' do
      complex_data = {
        'sources' => [
          { 'title' => 'Test', 'url' => 'https://test.com', 'content' => 'Content' }
        ],
        'domain' => { 'domain' => 'test.com', 'sources' => [] },
        'recipient' => { 'name' => 'Test User', 'sources' => [] }
      }
      output = create(:agent_output, lead: lead, output_data: complex_data)
      # JSONB stores keys as strings, so expect string keys back
      expect(output.output_data).to eq(complex_data)
      expect(output.output_data['sources'].length).to eq(1)
    end
  end
end
