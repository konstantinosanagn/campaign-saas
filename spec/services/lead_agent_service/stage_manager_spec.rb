require 'rails_helper'

RSpec.describe LeadAgentService::StageManager do
  let(:campaign) { double('Campaign') }
  let(:config_manager) { class_double('LeadAgentService::ConfigManager') }

  before do
    stub_const('LeadAgentService::ConfigManager', config_manager)
    allow(config_manager).to receive(:get_agent_config).and_return(double(enabled?: true))
    allow(Rails.logger).to receive(:info)
  end

  describe '.determine_available_actions' do
    context 'rewritten stage logic' do
      let(:stage) { 'rewritten' }
      let(:latest_writer) { double('Writer', id: 3, created_at: Time.now - 60) }
      let(:latest_critique) { double('Critique', id: 2, created_at: Time.now) }
      let(:lead) { double('Lead', id: 1, stage: stage, agent_outputs: double, campaign: campaign) }
      before do
        allow(LeadAgentService::StageManager).to receive(:latest_completed_writer).and_return(latest_writer)
        allow(LeadAgentService::StageManager).to receive(:latest_completed_critique).and_return(latest_critique)
        allow(LeadAgentService::StageManager).to receive(:calculate_rewrite_count).and_return(1)
        allow(AgentConstants).to receive(:rewritten_stage?).and_return(true)
        allow(lead).to receive(:reload)
        allow(lead).to receive(:association).and_return(double(reset: true))
        allow(campaign).to receive(:reload)
      end

      it 'adds CRITIQUE if critique is not newer than writer' do
        meets_min = true
        allow(LeadAgentService::StageManager).to receive(:critique_meets_min_score).and_return(meets_min)
        allow(latest_critique).to receive(:created_at).and_return(latest_writer.created_at - 10)
        actions = LeadAgentService::StageManager.determine_available_actions(lead)
        expect(actions).to include(AgentConstants::AGENT_CRITIQUE)
      end

      it 'adds WRITER if critique is newer but meets_min is false' do
        meets_min = false
        allow(LeadAgentService::StageManager).to receive(:critique_meets_min_score).and_return(meets_min)
        allow(latest_critique).to receive(:created_at).and_return(latest_writer.created_at + 10)
        actions = LeadAgentService::StageManager.determine_available_actions(lead)
        expect(actions).to include(AgentConstants::AGENT_WRITER)
      end

      it 'adds DESIGN if critique is newer and meets_min is true' do
        meets_min = true
        allow(LeadAgentService::StageManager).to receive(:critique_meets_min_score).and_return(meets_min)
        allow(latest_critique).to receive(:created_at).and_return(latest_writer.created_at + 10)
        actions = LeadAgentService::StageManager.determine_available_actions(lead)
        expect(actions).to include(AgentConstants::AGENT_DESIGN)
      end
    end

    context 'written stage logic' do
      let(:stage) { AgentConstants::STAGE_WRITTEN }
      let(:latest_critique) { double('Critique', id: 2, created_at: Time.now) }
      let(:lead) { double('Lead', id: 1, stage: stage, agent_outputs: double, campaign: campaign) }
      before do
        allow(AgentConstants).to receive(:rewritten_stage?).and_return(false)
        allow(LeadAgentService::StageManager).to receive(:latest_completed_critique).and_return(latest_critique)
        allow(LeadAgentService::StageManager).to receive(:calculate_rewrite_count).and_return(rewrite_count)
        allow(LeadAgentService::StageManager).to receive(:critique_meets_min_score).and_return(meets_min)
        allow(lead).to receive(:reload)
        allow(lead).to receive(:association).and_return(double(reset: true))
        allow(campaign).to receive(:reload)
      end

      let(:rewrite_count) { 1 }
      let(:meets_min) { true }

      it 'adds CRITIQUE if no critique' do
        allow(LeadAgentService::StageManager).to receive(:latest_completed_critique).and_return(nil)
        actions = LeadAgentService::StageManager.determine_available_actions(lead)
        expect(actions).to include(AgentConstants::AGENT_CRITIQUE)
      end

      it 'adds WRITER if critique failed and no rewrites' do
        allow(LeadAgentService::StageManager).to receive(:critique_meets_min_score).and_return(false)
        allow(LeadAgentService::StageManager).to receive(:calculate_rewrite_count).and_return(0)
        actions = LeadAgentService::StageManager.determine_available_actions(lead)
        expect(actions).to include(AgentConstants::AGENT_WRITER)
      end

      it 'adds CRITIQUE if critique failed and rewrites > 0' do
        allow(LeadAgentService::StageManager).to receive(:critique_meets_min_score).and_return(false)
        allow(LeadAgentService::StageManager).to receive(:calculate_rewrite_count).and_return(1)
        actions = LeadAgentService::StageManager.determine_available_actions(lead)
        expect(actions).to include(AgentConstants::AGENT_CRITIQUE)
      end

      it 'adds DESIGN if critique passed' do
        allow(LeadAgentService::StageManager).to receive(:critique_meets_min_score).and_return(true)
        actions = LeadAgentService::StageManager.determine_available_actions(lead)
        expect(actions).to include(AgentConstants::AGENT_DESIGN)
      end
    end

    context 'critiqued stage logic' do
      let(:stage) { AgentConstants::STAGE_CRITIQUED }
      let(:lead) { double('Lead', id: 1, stage: stage, agent_outputs: agent_outputs, campaign: campaign) }
      let(:agent_outputs) do
        double('AgentOutputs').tap do |ao|
          allow(ao).to receive(:where).and_return(ao)
          allow(ao).to receive(:order).and_return(ao)
          allow(ao).to receive(:first).and_return(double('Critique', id: 2, created_at: Time.now))
          allow(ao).to receive(:count).and_return(0)
          allow(ao).to receive(:pluck).with(:id, :created_at).and_return([])
        end
      end
      before do
        allow(AgentConstants).to receive(:rewritten_stage?).and_return(false)
        allow(lead).to receive(:reload)
        allow(lead).to receive(:association).and_return(double(reset: true))
        allow(campaign).to receive(:reload)
      end

      it 'adds WRITER if critique failed' do
        allow(LeadAgentService::StageManager).to receive(:critique_meets_min_score).and_return(false)
        actions = LeadAgentService::StageManager.determine_available_actions(lead)
        expect(actions).to include(AgentConstants::AGENT_WRITER)
      end

      it 'adds DESIGN if critique passed' do
        allow(LeadAgentService::StageManager).to receive(:critique_meets_min_score).and_return(true)
        actions = LeadAgentService::StageManager.determine_available_actions(lead)
        expect(actions).to include(AgentConstants::AGENT_DESIGN)
      end
    end
  end

  describe '.critique_meets_min_score' do
    it 'returns nil if critique_output is nil' do
      expect(described_class.send(:critique_meets_min_score, nil)).to be_nil
    end

    it 'returns value for string key' do
      critique_output = double('CritiqueOutput', output_data: { 'meets_min_score' => true })
      expect(described_class.send(:critique_meets_min_score, critique_output)).to eq(true)
    end

    it 'returns value for symbol key' do
      critique_output = double('CritiqueOutput', output_data: { meets_min_score: false })
      expect(described_class.send(:critique_meets_min_score, critique_output)).to eq(false)
    end

    it 'returns nil if key missing' do
      critique_output = double('CritiqueOutput', output_data: {})
      expect(described_class.send(:critique_meets_min_score, critique_output)).to be_nil
    end
  end

  describe '.critique_failed?' do
    it 'returns true if meets_min_score is false' do
      critique_output = double('CritiqueOutput', output_data: { meets_min_score: false })
      expect(described_class.send(:critique_failed?, critique_output)).to eq(true)
    end

    it 'returns false if meets_min_score is true' do
      critique_output = double('CritiqueOutput', output_data: { meets_min_score: true })
      expect(described_class.send(:critique_failed?, critique_output)).to eq(false)
    end
  end
end
