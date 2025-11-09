require 'rails_helper'

RSpec.describe LeadAgentService, type: :service do
  describe '.run_agents_for_lead' do
    let(:user) { create(:user) }
    let(:campaign) { create(:campaign, user: user) }
    let(:lead) { create(:lead, campaign: campaign, stage: 'queued', quality: '-') }
    let(:session) do
      {
        llm_api_key: 'test-gemini-key',
        tavily_api_key: 'test-tavily-key'
      }
    end

    context 'with valid API keys and successful agent execution' do
      before do
        # Mock agent services to return expected outputs
        allow_any_instance_of(SearchAgent).to receive(:run).and_return({
          company: lead.company,
          sources: [ { title: 'News Article', url: 'https://example.com' } ]
        })

        allow_any_instance_of(WriterAgent).to receive(:run).and_return({
          company: lead.company,
          email: 'Subject: Test Email\n\nBody content',
          recipient: lead.name
        })

        allow_any_instance_of(CritiqueAgent).to receive(:run).and_return({
          'critique' => nil
        })
      end

      it 'runs only the SEARCH agent for a queued lead' do
        # Create enabled config so agent actually runs
        create(:agent_config_search, campaign: campaign)

        result = described_class.run_agents_for_lead(lead, campaign, session)

        expect(result[:status]).to eq('completed')
        expect(result[:completed_agents]).to contain_exactly('SEARCH')
        expect(result[:failed_agents]).to be_empty
      end

      it 'creates agent output for the next agent' do
        # Create enabled config so agent actually runs
        create(:agent_config_search, campaign: campaign)

        expect {
          described_class.run_agents_for_lead(lead, campaign, session)
        }.to change(AgentOutput, :count).by(1)

        search_output = lead.agent_outputs.find_by(agent_name: 'SEARCH')
        expect(search_output).to be_present
        expect(search_output.status).to eq('completed')
      end

      it 'updates lead stage from queued to searched after running SEARCH' do
        create(:agent_config_search, campaign: campaign)

        described_class.run_agents_for_lead(lead, campaign, session)

        lead.reload
        expect(lead.stage).to eq('searched')
      end

      it 'does not update quality for SEARCH agent' do
        create(:agent_config_search, campaign: campaign)

        described_class.run_agents_for_lead(lead, campaign, session)

        lead.reload
        expect(lead.quality).to eq('-')
      end

      it 'runs WRITER agent for a searched lead' do
        lead.update!(stage: 'searched')
        create(:agent_output, lead: lead, agent_name: 'SEARCH', status: 'completed')
        create(:agent_config, campaign: campaign, agent_name: 'WRITER', enabled: true)

        result = described_class.run_agents_for_lead(lead, campaign, session)

        expect(result[:completed_agents]).to contain_exactly('WRITER')
      end

      it 'updates quality after running CRITIQUE agent' do
        lead.update!(stage: 'written')
        create(:agent_output_writer, lead: lead, agent_name: 'WRITER', status: 'completed')
        create(:agent_config, campaign: campaign, agent_name: 'CRITIQUE', enabled: true)

        result = described_class.run_agents_for_lead(lead, campaign, session)

        lead.reload
        expect(lead.quality).to eq('high')
      end

      it 'passes search output to writer agent' do
        lead.update!(stage: 'searched')
        search_result = {
          company: 'Test Corp',
          sources: [ { title: 'Article', url: 'http://test.com' } ]
        }
        create(:agent_output, lead: lead, agent_name: 'SEARCH', status: 'completed', output_data: search_result)
        create(:agent_config, campaign: campaign, agent_name: 'WRITER', enabled: true)

        writer_expectation = nil
        allow_any_instance_of(WriterAgent).to receive(:run) do |instance, *args|
          writer_expectation = args
          { company: 'Test Corp', email: 'Test', recipient: lead.name }
        end

        described_class.run_agents_for_lead(lead, campaign, session)

        # Writer should receive search results as first argument
        expect(writer_expectation.first).to include(sources: search_result[:sources])
      end

      it 'passes writer output to critique agent' do
        lead.update!(stage: 'written')
        writer_result = {
          company: 'Test Corp',
          email: 'Test Email Content'
        }
        create(:agent_output, lead: lead, agent_name: 'WRITER', status: 'completed', output_data: writer_result.with_indifferent_access)
        create(:agent_config, campaign: campaign, agent_name: 'CRITIQUE', enabled: true)

        critique_expectation = nil
        allow_any_instance_of(CritiqueAgent).to receive(:run) do |instance, *args|
          critique_expectation = args
          { 'critique' => nil }
        end

        described_class.run_agents_for_lead(lead, campaign, session)

        # Critique should receive formatted writer output with email_content
        expect(critique_expectation.first).to include('email_content')
        expect(critique_expectation.first['email_content']).to eq('Test Email Content')
      end
    end

    context 'when API keys are missing' do
      let(:empty_session) { {} }

      it 'returns failed status with error message' do
        result = described_class.run_agents_for_lead(lead, campaign, empty_session)

        expect(result[:status]).to eq('failed')
        expect(result[:error]).to match(/Missing API keys/)
        expect(result[:outputs]).to eq({})
      end

      it 'does not create any agent outputs' do
        expect {
          described_class.run_agents_for_lead(lead, campaign, empty_session)
        }.not_to change(AgentOutput, :count)
      end

      it 'does not update lead stage' do
        original_stage = lead.stage
        described_class.run_agents_for_lead(lead, campaign, empty_session)

        lead.reload
        expect(lead.stage).to eq(original_stage)
      end
    end

    context 'when an agent fails' do
      before do
        allow_any_instance_of(SearchAgent).to receive(:run).and_raise(StandardError, 'Search failed')
      end

      it 'does not advance stage when an agent fails' do
        # Create enabled config to allow agent to fail
        create(:agent_config_search, campaign: campaign)

        result = described_class.run_agents_for_lead(lead, campaign, session)

        expect(result[:failed_agents]).to include('SEARCH')
        expect(result[:completed_agents]).to be_empty
      end

      it 'stores error in agent output' do
        create(:agent_config_search, campaign: campaign)

        described_class.run_agents_for_lead(lead, campaign, session)

        search_output = lead.agent_outputs.find_by(agent_name: 'SEARCH')
        expect(search_output.status).to eq('failed')
        expect(search_output.error_message).to be_present
      end

      it 'does not advance stage when SEARCH fails' do
        create(:agent_config_search, campaign: campaign)

        described_class.run_agents_for_lead(lead, campaign, session)

        lead.reload
        # Stage should remain at queued
        expect(lead.stage).to eq('queued')
      end
    end

    context 'when agent config is disabled' do
      before do
        create(:agent_config, campaign: campaign, agent_name: 'SEARCH', enabled: false)
      end

      it 'skips disabled agents and advances stage' do
        result = described_class.run_agents_for_lead(lead, campaign, session)

        expect(result[:completed_agents]).to be_empty
        expect(result[:failed_agents]).to be_empty
      end

      it 'advances stage even when agent is disabled' do
        described_class.run_agents_for_lead(lead, campaign, session)

        lead.reload
        expect(lead.stage).to eq('searched')
      end

      it 'does not create output for disabled agent' do
        described_class.run_agents_for_lead(lead, campaign, session)

        search_output = lead.agent_outputs.find_by(agent_name: 'SEARCH')
        expect(search_output).to be_nil
      end
    end

    context 'agent config retrieval' do
      it 'creates default config for SEARCH agent when not exists' do
        expect {
          described_class.run_agents_for_lead(lead, campaign, session)
        }.to change(AgentConfig, :count).by(1)

        expect(campaign.agent_configs.pluck(:agent_name)).to contain_exactly('SEARCH')
      end

      it 'uses existing configs when available' do
        create(:agent_config, campaign: campaign, agent_name: 'SEARCH', settings: {})

        described_class.run_agents_for_lead(lead, campaign, session)

        # Should not create duplicate
        expect(campaign.agent_configs.where(agent_name: 'SEARCH').count).to eq(1)
      end
    end

    context 'return format' do
      before do
        allow_any_instance_of(SearchAgent).to receive(:run).and_return({ company: 'Test', sources: [] })
      end

      it 'returns status, outputs, lead, and agent lists' do
        result = described_class.run_agents_for_lead(lead, campaign, session)

        expect(result).to have_key(:status)
        expect(result).to have_key(:outputs)
        expect(result).to have_key(:lead)
        expect(result).to have_key(:completed_agents)
        expect(result).to have_key(:failed_agents)
      end

      it 'outputs hash contains only the executed agent result' do
        # Create enabled config so agent actually runs
        create(:agent_config_search, campaign: campaign)

        result = described_class.run_agents_for_lead(lead, campaign, session)

        expect(result[:outputs]).to have_key('SEARCH')
        expect(result[:outputs]).not_to have_key('WRITER')
        expect(result[:outputs]).not_to have_key('CRITIQUE')
      end

      it 'returns updated lead with current attributes' do
        result = described_class.run_agents_for_lead(lead, campaign, session)

        expect(result[:lead].stage).to eq('searched')
        expect(result[:lead].quality).to eq('-')
      end

      it 'returns completed status when lead is already at final stage' do
        lead.update!(stage: 'completed')

        result = described_class.run_agents_for_lead(lead, campaign, session)

        expect(result[:status]).to eq('completed')
        expect(result[:error]).to match(/already reached the final stage/)
      end
    end
  end
end
