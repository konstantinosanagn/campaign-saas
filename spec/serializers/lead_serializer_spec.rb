require 'rails_helper'

RSpec.describe LeadSerializer do
  let(:lead) { Lead.new(id: 1, name: 'Test', email: 'test@example.com', title: 'CEO', company: 'TestCo', campaign_id: 1, stage: 'new', quality: 'high', created_at: Time.now, updated_at: Time.now) }

  def build_agent_output(output_data)
    AgentOutput.new(agent_name: 'CRITIQUE', status: 'completed', output_data: output_data, created_at: Time.now)
  end

  describe '#critique_score' do
    it 'returns nil if no critique agent output' do
      allow(lead).to receive(:agent_outputs).and_return(AgentOutput.none)
      serializer = LeadSerializer.new(lead)
      expect(serializer.send(:critique_score)).to be_nil
    end

    it 'returns nil if score is missing in output_data' do
      agent_output = build_agent_output({})
      allow(lead).to receive_message_chain(:agent_outputs, :where, :order, :first).and_return(agent_output)
      serializer = LeadSerializer.new(lead)
      expect(serializer.send(:critique_score)).to be_nil
    end

    it 'returns integer score if present as string key' do
      agent_output = build_agent_output({ 'score' => 7 })
      allow(lead).to receive_message_chain(:agent_outputs, :where, :order, :first).and_return(agent_output)
      serializer = LeadSerializer.new(lead)
      expect(serializer.send(:critique_score)).to eq(7)
    end

    it 'returns integer score if present as symbol key' do
      agent_output = build_agent_output({ score: 8 })
      allow(lead).to receive_message_chain(:agent_outputs, :where, :order, :first).and_return(agent_output)
      serializer = LeadSerializer.new(lead)
      expect(serializer.send(:critique_score)).to eq(8)
    end

    it 'returns nil if score is not numeric' do
      agent_output = build_agent_output({ 'score' => 'bad' })
      allow(lead).to receive_message_chain(:agent_outputs, :where, :order, :first).and_return(agent_output)
      serializer = LeadSerializer.new(lead)
      expect(serializer.send(:critique_score)).to be_nil
    end
  end

  describe '#critique_meets_min_score' do
    it 'returns nil if no critique agent output' do
      allow(lead).to receive(:agent_outputs).and_return(AgentOutput.none)
      serializer = LeadSerializer.new(lead)
      expect(serializer.send(:critique_meets_min_score)).to be_nil
    end

    it 'returns nil if meets_min_score is missing in output_data' do
      agent_output = build_agent_output({})
      allow(lead).to receive_message_chain(:agent_outputs, :where, :order, :first).and_return(agent_output)
      serializer = LeadSerializer.new(lead)
      expect(serializer.send(:critique_meets_min_score)).to be_nil
    end

    it 'returns value if meets_min_score is present as string key' do
      agent_output = build_agent_output({ 'meets_min_score' => true })
      allow(lead).to receive_message_chain(:agent_outputs, :where, :order, :first).and_return(agent_output)
      serializer = LeadSerializer.new(lead)
      expect(serializer.send(:critique_meets_min_score)).to eq(true)
    end

    it 'returns value if meets_min_score is present as symbol key' do
      agent_output = build_agent_output({ meets_min_score: false })
      allow(lead).to receive_message_chain(:agent_outputs, :where, :order, :first).and_return(agent_output)
      serializer = LeadSerializer.new(lead)
      result = serializer.send(:critique_meets_min_score)
      expect([ false, nil ]).to include(result)
    end
  end
end
