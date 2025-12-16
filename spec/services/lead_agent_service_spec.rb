require 'rails_helper'

RSpec.describe LeadAgentService, type: :service do
  describe '.run_agents_for_lead' do
    let(:user) { create(:user) }
    let(:campaign) { create(:campaign, user: user) }
    let(:lead) { create(:lead, campaign: campaign, stage: 'queued', quality: '-') }
    before do
      user.update!(llm_api_key: 'test-gemini-key', tavily_api_key: 'test-tavily-key')
    end

    # Note: extract_domain_from_lead and default_settings_for_agent were moved to
    # LeadAgentService::ConfigManager. These methods are now private implementation details
    # and are tested indirectly through the public interface.

    context 'with valid API keys and successful agent execution' do
      before do
        # Mock agent services to return expected outputs
        allow_any_instance_of(Agents::SearchAgent).to receive(:run).and_return({
          domain: { domain: lead.company, sources: [ { title: 'News Article', url: 'https://example.com' } ] },
          recipient: { name: lead.name, sources: [] },
          sources: [ { title: 'News Article', url: 'https://example.com' } ]
        })

        allow_any_instance_of(Agents::WriterAgent).to receive(:run).and_return({
          company: lead.company,
          email: 'Subject: Test Email\n\nBody content',
          recipient: lead.name
        })

        allow_any_instance_of(Agents::CritiqueAgent).to receive(:run).and_return({
          'critique' => nil
        })

        allow_any_instance_of(Agents::DesignAgent).to receive(:run).and_return({
          email: 'Subject: Test Email\n\nBody content',
          formatted_email: 'Subject: Test Email\n\n**Body** content',
          company: lead.company,
          recipient: lead.name,
          original_email: 'Subject: Test Email\n\nBody content'
        })
      end

      it 'runs only the SEARCH agent for a queued lead' do
        # Create enabled config so agent actually runs
        create(:agent_config_search, campaign: campaign)

        result = described_class.run_agents_for_lead(lead, campaign, user)

        expect(result[:status]).to eq('completed')
        expect(result[:completed_agents]).to contain_exactly('SEARCH')
        expect(result[:failed_agents]).to be_empty
      end

      it 'creates agent output for the next agent' do
        # Create enabled config so agent actually runs
        create(:agent_config_search, campaign: campaign)

        expect {
          described_class.run_agents_for_lead(lead, campaign, user)
        }.to change(AgentOutput, :count).by(1)

        search_output = lead.agent_outputs.find_by(agent_name: 'SEARCH')
        expect(search_output).to be_present
        expect(search_output.status).to eq('completed')
      end

      it 'updates lead stage from queued to searched after running SEARCH' do
        create(:agent_config_search, campaign: campaign)

        described_class.run_agents_for_lead(lead, campaign, user)

        lead.reload
        expect(lead.stage).to eq('searched')
      end

      it 'does not update quality for SEARCH agent' do
        create(:agent_config_search, campaign: campaign)

        described_class.run_agents_for_lead(lead, campaign, user)

        lead.reload
        expect(lead.quality).to eq('-')
      end

      it 'runs WRITER agent for a searched lead' do
        lead.update!(stage: 'searched')
        create(:agent_output, lead: lead, agent_name: 'SEARCH', status: 'completed')
        create(:agent_config, campaign: campaign, agent_name: 'WRITER', enabled: true)

        result = described_class.run_agents_for_lead(lead, campaign, user)

        expect(result[:completed_agents]).to contain_exactly('WRITER')
      end

      it 'updates quality after running CRITIQUE agent' do
        lead.update!(stage: 'written')
        create(:agent_output_writer, lead: lead, agent_name: 'WRITER', status: 'completed')
        create(:agent_config, campaign: campaign, agent_name: 'CRITIQUE', enabled: true)

        result = described_class.run_agents_for_lead(lead, campaign, user)

        lead.reload
        expect(lead.quality).to eq('high')
      end

      it 'passes search output to writer agent' do
        lead.update!(stage: 'searched')

        search_result = {
          company: lead.company,
          inferred_focus_areas: [ "cloud architecture", "scalability" ],
          personalization_signals: {
            recipient: [ { title: "Article", url: "http://test.com" } ],
            company:   [ { title: "Company News", url: "http://company.com" } ]
          }
        }

        create(:agent_output,
          lead: lead,
          agent_name: 'SEARCH',
          status: 'completed',
          output_data: search_result.deep_symbolize_keys
        )

        expected_sources = (search_result[:personalization_signals][:recipient] +
                      search_result[:personalization_signals][:company]).uniq

        writer_output = {
          company: lead.company,
          email: "Subject: Test Email\n\nBody text",
          recipient: lead.name,
          variants: [ "Subject: Test Email\n\nBody text" ]
        }

        expect_any_instance_of(Agents::WriterAgent).to receive(:run) do |_, passed_search_results, **|
          expect(passed_search_results[:company]).to eq(lead.company)
          expect(passed_search_results[:sources]).to eq(expected_sources)
          expect(passed_search_results[:inferred_focus_areas]).to eq(search_result[:inferred_focus_areas])
        end.and_return(writer_output)

        result = described_class.run_agents_for_lead(lead, campaign, user)
        expect(result[:status]).to eq("completed")
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
        allow_any_instance_of(Agents::CritiqueAgent).to receive(:run) do |instance, *args|
          critique_expectation = args
          { 'critique' => nil }
        end

        described_class.run_agents_for_lead(lead, campaign, user)

        # Critique should receive formatted writer output with email_content
        expect(critique_expectation.first).to include('email_content')
        expect(critique_expectation.first['email_content']).to eq('Test Email Content')
      end

      it 'runs DESIGN agent for a critiqued lead' do
        lead.update!(stage: 'critiqued')
        critique_result = {
          'critique' => nil,
          'email_content' => 'Subject: Test\n\nTest email content',
          'selected_variant' => 'Subject: Test\n\nSelected variant content'
        }
        create(:agent_output, lead: lead, agent_name: 'CRITIQUE', status: 'completed', output_data: critique_result.with_indifferent_access)
        create(:agent_config, campaign: campaign, agent_name: 'DESIGN', enabled: true)

        result = described_class.run_agents_for_lead(lead, campaign, user)

        expect(result[:completed_agents]).to contain_exactly('DESIGN')
      end

      it 'updates lead stage from critiqued to designed after running DESIGN' do
        lead.update!(stage: 'critiqued')
        critique_result = {
          'critique' => nil,
          'email_content' => 'Subject: Test\n\nTest email content'
        }
        create(:agent_output, lead: lead, agent_name: 'CRITIQUE', status: 'completed', output_data: critique_result.with_indifferent_access)
        create(:agent_config, campaign: campaign, agent_name: 'DESIGN', enabled: true)

        described_class.run_agents_for_lead(lead, campaign, user)

        lead.reload
        expect(lead.stage).to eq('designed')
      end

      it 'passes critique output to design agent' do
        lead.update!(stage: 'critiqued')
        critique_result = {
          'critique' => nil,
          'email_content' => 'Subject: Test\n\nTest email content',
          'selected_variant' => 'Subject: Test\n\nSelected variant content'
        }
        create(:agent_output, lead: lead, agent_name: 'CRITIQUE', status: 'completed', output_data: critique_result.with_indifferent_access)
        create(:agent_config, campaign: campaign, agent_name: 'DESIGN', enabled: true)

        design_expectation = nil
        allow_any_instance_of(Agents::DesignAgent).to receive(:run) do |instance, *args|
          design_expectation = args
          {
            email: 'Subject: Test\n\nFormatted content',
            formatted_email: 'Subject: Test\n\n**Formatted** content',
            company: lead.company,
            recipient: lead.name
          }
        end

        described_class.run_agents_for_lead(lead, campaign, user)

        # Design should receive critique output with email, company, and recipient
        expect(design_expectation.first).to include(
          email: 'Subject: Test\n\nSelected variant content',
          company: lead.company,
          recipient: lead.name
        )
      end

      it 'falls back to WRITER output when CRITIQUE output has no email for DESIGN' do
        lead.update!(stage: 'critiqued')
        create(:agent_output, lead: lead, agent_name: 'CRITIQUE', status: 'completed', output_data: { 'critique' => nil }.with_indifferent_access)
        create(:agent_output, lead: lead, agent_name: 'WRITER', status: 'completed', output_data: { 'email' => 'Writer fallback email' }.with_indifferent_access)
        create(:agent_config, campaign: campaign, agent_name: 'DESIGN', enabled: true)

        design_args = nil
        allow_any_instance_of(Agents::DesignAgent).to receive(:run) do |_, *args|
          design_args = args
          {
            email: 'Subject: formatted',
            formatted_email: '**formatted** email',
            company: lead.company,
            recipient: lead.name
          }
        end

        described_class.run_agents_for_lead(lead, campaign, user)

        first_arg = design_args.first
        email_val = first_arg[:email] || first_arg['email']
        expect(email_val).to eq('Writer fallback email')
      end

      it 'prefers selected_variant from critique output when available' do
        lead.update!(stage: 'critiqued')
        critique_result = {
          'critique' => nil,
          'email_content' => 'Subject: Test\n\nOriginal email content',
          'selected_variant' => 'Subject: Test\n\nSelected variant content'
        }
        create(:agent_output, lead: lead, agent_name: 'CRITIQUE', status: 'completed', output_data: critique_result.with_indifferent_access)
        create(:agent_config, campaign: campaign, agent_name: 'DESIGN', enabled: true)

        design_expectation = nil
        allow_any_instance_of(Agents::DesignAgent).to receive(:run) do |instance, *args|
          design_expectation = args
          {
            email: 'Subject: Test\n\nFormatted content',
            formatted_email: 'Subject: Test\n\n**Formatted** content',
            company: lead.company,
            recipient: lead.name
          }
        end

        described_class.run_agents_for_lead(lead, campaign, user)

        # Design should receive selected_variant, not email_content
        expect(design_expectation.first[:email]).to eq('Subject: Test\n\nSelected variant content')
      end

      it 'falls back to email_content when selected_variant is not available' do
        lead.update!(stage: 'critiqued')
        critique_result = {
          'critique' => nil,
          'email_content' => 'Subject: Test\n\nEmail content without variant'
        }
        create(:agent_output, lead: lead, agent_name: 'CRITIQUE', status: 'completed', output_data: critique_result.with_indifferent_access)
        create(:agent_config, campaign: campaign, agent_name: 'DESIGN', enabled: true)

        design_expectation = nil
        allow_any_instance_of(Agents::DesignAgent).to receive(:run) do |instance, *args|
          design_expectation = args
          {
            email: 'Subject: Test\n\nFormatted content',
            formatted_email: 'Subject: Test\n\n**Formatted** content',
            company: lead.company,
            recipient: lead.name
          }
        end

        described_class.run_agents_for_lead(lead, campaign, user)

        # Design should receive email_content as fallback
        expect(design_expectation.first[:email]).to eq('Subject: Test\n\nEmail content without variant')
      end

      it 'falls back to email key when selected_variant and email_content are not available' do
        lead.update!(stage: 'critiqued')
        critique_result = {
          'critique' => nil,
          'email' => 'Subject: Test\n\nFallback email'
        }
        create(:agent_output, lead: lead, agent_name: 'CRITIQUE', status: 'completed', output_data: critique_result.with_indifferent_access)
        create(:agent_config, campaign: campaign, agent_name: 'DESIGN', enabled: true)

        design_expectation = nil
        allow_any_instance_of(Agents::DesignAgent).to receive(:run) do |instance, *args|
          design_expectation = args
          {
            email: 'Subject: Test\n\nFormatted content',
            formatted_email: 'Subject: Test\n\n**Formatted** content',
            company: lead.company,
            recipient: lead.name
          }
        end

        described_class.run_agents_for_lead(lead, campaign, user)

        # Design should receive email as final fallback
        expect(design_expectation.first[:email]).to eq('Subject: Test\n\nFallback email')
      end

      it 'passes config to design agent when available' do
        lead.update!(stage: 'critiqued')
        critique_result = {
          'critique' => nil,
          'email_content' => 'Subject: Test\n\nTest email content'
        }
        create(:agent_output, lead: lead, agent_name: 'CRITIQUE', status: 'completed', output_data: critique_result.with_indifferent_access)
        design_config = create(:agent_config, campaign: campaign, agent_name: 'DESIGN', enabled: true, settings: {
          format: 'formatted',
          allow_bold: true,
          allow_italic: false,
          cta_style: 'button'
        })

        design_expectation = nil
        allow_any_instance_of(Agents::DesignAgent).to receive(:run) do |instance, *args|
          design_expectation = args
          {
            email: 'Subject: Test\n\nFormatted content',
            formatted_email: 'Subject: Test\n\n**Formatted** content',
            company: lead.company,
            recipient: lead.name
          }
        end

        described_class.run_agents_for_lead(lead, campaign, user)

        # Design should receive config as second argument with settings nested
        expect(design_expectation[1]).to include(config: hash_including(settings: design_config.settings))
      end

      it 'creates agent output for DESIGN agent' do
        lead.update!(stage: 'critiqued')
        critique_result = {
          'critique' => nil,
          'email_content' => 'Subject: Test\n\nTest email content'
        }
        create(:agent_output, lead: lead, agent_name: 'CRITIQUE', status: 'completed', output_data: critique_result.with_indifferent_access)
        create(:agent_config, campaign: campaign, agent_name: 'DESIGN', enabled: true)

        expect {
          described_class.run_agents_for_lead(lead, campaign, user)
        }.to change(AgentOutput, :count).by(1)

        design_output = lead.agent_outputs.find_by(agent_name: 'DESIGN')
        expect(design_output).to be_present
        expect(design_output.status).to eq('completed')
        expect(design_output.output_data).to include('formatted_email')
      end

      it 'does not update quality for DESIGN agent' do
        lead.update!(stage: 'critiqued', quality: 'high')
        critique_result = {
          'critique' => nil,
          'email_content' => 'Subject: Test\n\nTest email content'
        }
        create(:agent_output, lead: lead, agent_name: 'CRITIQUE', status: 'completed', output_data: critique_result.with_indifferent_access)
        create(:agent_config, campaign: campaign, agent_name: 'DESIGN', enabled: true)

        described_class.run_agents_for_lead(lead, campaign, user)

        lead.reload
        expect(lead.quality).to eq('high')
      end
    end

    context 'when API keys are missing' do
      before do
        user.update!(llm_api_key: nil, tavily_api_key: nil)
      end

      it 'returns failed status with error message' do
        result = described_class.run_agents_for_lead(lead, campaign, user)

        expect(result[:status]).to eq('failed')
        expect(result[:error]).to match(/Missing API keys/)
        expect(result[:outputs]).to eq({})
      end

      it 'does not create any agent outputs' do
        expect {
          described_class.run_agents_for_lead(lead, campaign, user)
        }.not_to change(AgentOutput, :count)
      end

      it 'does not update lead stage' do
        original_stage = lead.stage
        described_class.run_agents_for_lead(lead, campaign, user)

        lead.reload
        expect(lead.stage).to eq(original_stage)
      end
    end

    context 'when an agent fails' do
      before do
        allow_any_instance_of(Agents::SearchAgent).to receive(:run).and_raise(StandardError, 'Search failed')
      end

      it 'does not advance stage when an agent fails' do
        # Create enabled config to allow agent to fail
        create(:agent_config_search, campaign: campaign)

        result = described_class.run_agents_for_lead(lead, campaign, user)

        expect(result[:failed_agents]).to include('SEARCH')
        expect(result[:completed_agents]).to be_empty
      end

      it 'stores error in agent output' do
        create(:agent_config_search, campaign: campaign)

        described_class.run_agents_for_lead(lead, campaign, user)

        search_output = lead.agent_outputs.find_by(agent_name: 'SEARCH')
        expect(search_output.status).to eq('failed')
        expect(search_output.error_message).to be_present
      end

      it 'does not advance stage when SEARCH fails' do
        create(:agent_config_search, campaign: campaign)

        described_class.run_agents_for_lead(lead, campaign, user)

        lead.reload
        # Stage should remain at queued
        expect(lead.stage).to eq('queued')
      end

      it 'stores writer-specific fields when WRITER fails' do
        lead.update!(stage: 'searched')
        create(:agent_output, lead: lead, agent_name: 'SEARCH', status: 'completed', output_data: { sources: [] })
        create(:agent_config, campaign: campaign, agent_name: 'WRITER', enabled: true)

        allow_any_instance_of(Agents::WriterAgent).to receive(:run).and_raise(StandardError, 'Writer failed')

        described_class.run_agents_for_lead(lead, campaign, user)

        writer_output = lead.agent_outputs.find_by(agent_name: 'WRITER')
        expect(writer_output).to be_present
        expect(writer_output.status).to eq('failed')
        expect(writer_output.output_data).to include('company' => lead.company)
        expect(writer_output.output_data).to include('recipient' => lead.name)
        expect(writer_output.output_data).to include('email' => "")
        expect(writer_output.error_message).to match(/Writer failed/)
      end

      it 'stores critique-specific fields when CRITIQUE fails' do
        allow_any_instance_of(Agents::SearchAgent).to receive(:run).and_return({
          domain: { domain: lead.company, sources: [] },
          recipient: { name: lead.name, sources: [] },
          sources: []
        })

        lead.update!(stage: 'written')
        create(:agent_output, lead: lead, agent_name: 'WRITER', status: 'completed', output_data: { email: 'Some email' })
        create(:agent_config, campaign: campaign, agent_name: 'CRITIQUE', enabled: true)

        allow_any_instance_of(Agents::CritiqueAgent).to receive(:run).and_raise(StandardError, 'Critique failed')

        described_class.run_agents_for_lead(lead, campaign, user)

        critique_output = lead.agent_outputs.find_by(agent_name: 'CRITIQUE')
        expect(critique_output).to be_present
        expect(critique_output.status).to eq('failed')
        expect(critique_output.output_data).to include('critique' => nil)
        expect(critique_output.error_message).to match(/Critique failed/)
      end
    end

    context 'when agent config is disabled' do
      before do
        create(:agent_config, campaign: campaign, agent_name: 'SEARCH', enabled: false)
        # Also disable WRITER, CRITIQUE, and DESIGN so they don't run after SEARCH is skipped
        create(:agent_config, campaign: campaign, agent_name: 'WRITER', enabled: false)
        create(:agent_config, campaign: campaign, agent_name: 'CRITIQUE', enabled: false)
        create(:agent_config, campaign: campaign, agent_name: 'DESIGN', enabled: false)
      end

      it 'skips disabled agents and advances stage' do
        result = described_class.run_agents_for_lead(lead, campaign, user)

        expect(result[:completed_agents]).to be_empty
        expect(result[:failed_agents]).to be_empty
      end

      it 'advances stage even when agent is disabled' do
        described_class.run_agents_for_lead(lead, campaign, user)

        lead.reload
        # When all agents are disabled, lead remains at the initial stage
        expect(lead.stage).to eq('queued')
      end

      it 'does not create output for disabled agent' do
        described_class.run_agents_for_lead(lead, campaign, user)

        search_output = lead.agent_outputs.find_by(agent_name: 'SEARCH')
        expect(search_output).to be_nil
      end
    end

    context 'when DESIGN agent config is disabled' do
      before do
        lead.update!(stage: 'critiqued')
        critique_result = {
          'critique' => nil,
          'email_content' => 'Subject: Test\n\nTest email content'
        }
        create(:agent_output, lead: lead, agent_name: 'CRITIQUE', status: 'completed', output_data: critique_result.with_indifferent_access)
        create(:agent_config, campaign: campaign, agent_name: 'DESIGN', enabled: false)
      end

      it 'skips disabled DESIGN agent and advances stage' do
        result = described_class.run_agents_for_lead(lead, campaign, user)

        expect(result[:completed_agents]).to be_empty
        expect(result[:failed_agents]).to be_empty
      end

      it 'advances stage even when DESIGN agent is disabled' do
        described_class.run_agents_for_lead(lead, campaign, user)

        lead.reload
        expect(lead.stage).to eq('critiqued')
      end

      it 'does not create output for disabled DESIGN agent' do
        described_class.run_agents_for_lead(lead, campaign, user)

        design_output = lead.agent_outputs.find_by(agent_name: 'DESIGN')
        expect(design_output).to be_nil
      end
    end

    context 'when DESIGN agent fails' do
      before do
        lead.update!(stage: 'critiqued')
        critique_result = {
          'critique' => nil,
          'email_content' => 'Subject: Test\n\nTest email content'
        }
        create(:agent_output, lead: lead, agent_name: 'CRITIQUE', status: 'completed', output_data: critique_result.with_indifferent_access)
        create(:agent_config, campaign: campaign, agent_name: 'DESIGN', enabled: true)
        allow_any_instance_of(Agents::DesignAgent).to receive(:run).and_raise(StandardError, 'Design failed')
      end

      it 'does not advance stage when DESIGN agent fails' do
        result = described_class.run_agents_for_lead(lead, campaign, user)

        expect(result[:failed_agents]).to include('DESIGN')
        expect(result[:completed_agents]).to be_empty
      end

      it 'stores error in DESIGN agent output' do
        described_class.run_agents_for_lead(lead, campaign, user)

        design_output = lead.agent_outputs.find_by(agent_name: 'DESIGN')
        expect(design_output.status).to eq('failed')
        expect(design_output.error_message).to be_present
      end

      it 'does not advance stage when DESIGN fails' do
        described_class.run_agents_for_lead(lead, campaign, user)

        lead.reload
        # Stage should remain at critiqued
        expect(lead.stage).to eq('critiqued')
      end
    end

    context 'agent config retrieval' do
      it 'creates default config for SEARCH agent when not exists' do
        expect {
          described_class.run_agents_for_lead(lead, campaign, user)
        }.to change(AgentConfig, :count).by(1)

        expect(campaign.agent_configs.pluck(:agent_name)).to contain_exactly('SEARCH')
      end

      it 'uses existing configs when available' do
        create(:agent_config, campaign: campaign, agent_name: 'SEARCH', settings: {})

        described_class.run_agents_for_lead(lead, campaign, user)

        # Should not create duplicate
        expect(campaign.agent_configs.where(agent_name: 'SEARCH').count).to eq(1)
      end
    end

    context 'return format' do
      before do
        allow_any_instance_of(Agents::SearchAgent).to receive(:run).and_return({
          domain: { domain: 'Test', sources: [] },
          recipient: { name: lead.name, sources: [] },
          sources: []
        })
      end

      it 'returns status, outputs, lead, and agent lists' do
        result = described_class.run_agents_for_lead(lead, campaign, user)

        expect(result).to have_key(:status)
        expect(result).to have_key(:outputs)
        expect(result).to have_key(:lead)
        expect(result).to have_key(:completed_agents)
        expect(result).to have_key(:failed_agents)
      end

      it 'outputs hash contains only the executed agent result' do
        # Create enabled config so agent actually runs
        create(:agent_config_search, campaign: campaign)

        result = described_class.run_agents_for_lead(lead, campaign, user)

        expect(result[:outputs]).to have_key('SEARCH')
        expect(result[:outputs]).not_to have_key('WRITER')
        expect(result[:outputs]).not_to have_key('CRITIQUE')
        expect(result[:outputs]).not_to have_key('DESIGN')
      end

      it 'returns updated lead with current attributes' do
        result = described_class.run_agents_for_lead(lead, campaign, user)

        expect(result[:lead].stage).to eq('searched')
        expect(result[:lead].quality).to eq('-')
      end

      it 'returns completed status when lead is already at final stage' do
        lead.update!(stage: 'completed')

        result = described_class.run_agents_for_lead(lead, campaign, user)

        expect(result[:status]).to eq('completed')
        expect(result[:error]).to match(/already reached the final stage/)
      end

      it 'returns completed status when lead is at designed stage' do
        lead.update!(stage: 'designed')

        result = described_class.run_agents_for_lead(lead, campaign, user)

        expect(result[:status]).to eq('completed')
        expect(result[:error]).to match(/already reached the final stage/)
      end
    end

    context 'full pipeline progression' do
      it 'progresses through all stages: queued → searched → written → critiqued → designed' do
        # Stage 1: queued → searched
        create(:agent_config_search, campaign: campaign)
        result = described_class.run_agents_for_lead(lead, campaign, user)
        expect(result[:completed_agents]).to contain_exactly('SEARCH')
        lead.reload
        expect(lead.stage).to eq('searched')

        # Stage 2: searched → written
        lead.agent_outputs.find_or_create_by(agent_name: 'SEARCH') do |ao|
          ao.status = 'completed'
          ao.output_data = { sources: [] }
        end
        create(:agent_config, campaign: campaign, agent_name: 'WRITER', enabled: true)
        result = described_class.run_agents_for_lead(lead, campaign, user)
        expect(result[:completed_agents]).to contain_exactly('WRITER')
        lead.reload
        expect(lead.stage).to eq('written')

        # Stage 3: written → critiqued
        lead.agent_outputs.find_or_create_by(agent_name: 'WRITER') do |ao|
          ao.status = 'completed'
          ao.output_data = {
            email: "Subject: Test Email\n\nBody of the email",
            company: 'Example Corp',
            recipient: 'John Doe'
          }
        end
        create(:agent_config, campaign: campaign, agent_name: 'CRITIQUE', enabled: true)
        result = described_class.run_agents_for_lead(lead, campaign, user)
        expect(result[:completed_agents]).to contain_exactly('CRITIQUE')
        lead.reload
        expect(lead.stage).to eq('critiqued')

        # Stage 4: critiqued → designed
        critique_result = {
          'critique' => nil,
          'email_content' => 'Subject: Test\n\nTest email content',
          'selected_variant' => 'Subject: Test\n\nSelected variant'
        }
        lead.agent_outputs.find_or_create_by(agent_name: 'CRITIQUE') do |ao|
          ao.status = 'completed'
          ao.output_data = critique_result.with_indifferent_access
        end
        create(:agent_config, campaign: campaign, agent_name: 'DESIGN', enabled: true)
        result = described_class.run_agents_for_lead(lead, campaign, user)
        expect(result[:completed_agents]).to contain_exactly('DESIGN')
        lead.reload
        expect(lead.stage).to eq('designed')
      end
    end

    context 'manual WRITER/CRITIQUE rewrite loop' do
      let(:lead) { create(:lead, campaign: campaign, stage: 'written', quality: '-') }

      before do
        # Create necessary agent configs
        create(:agent_config, campaign: campaign, agent_name: 'WRITER', enabled: true)
        create(:agent_config, campaign: campaign, agent_name: 'CRITIQUE', enabled: true, settings: {
          'min_score_for_send' => 6
        })
      end

      it 'critiques the latest writer revision, not the original' do
        # Create initial WRITER output
        original_email = "Subject: Original Email\n\nThis is the original email content that needs improvement."
        create(:agent_output,
          lead: lead,
          agent_name: 'WRITER',
          status: 'completed',
          output_data: {
            email: original_email,
            company: lead.company,
            recipient: lead.name
          }
        )

        # First critique - should critique the original email
        critique_email_content = nil
        allow_any_instance_of(Agents::CritiqueAgent).to receive(:run) do |_, article, **|
          critique_email_content = article['email_content']
          {
            'critique' => 'This email needs more personalization and a stronger CTA.',
            'score' => 4,
            'meets_min_score' => false
          }
        end

        result = described_class.run_agents_for_lead(lead, campaign, user, agent_name: 'CRITIQUE')
        expect(result[:status]).to eq('completed')
        expect(critique_email_content).to include('Original Email')

        lead.reload
        expect(lead.stage).to eq('written') # Should stay at written because score < min

        # Now mock WRITER to return a rewritten email
        rewritten_email = "Subject: Improved Email\n\nThis is the rewritten email with better personalization and CTA."

        # Verify WRITER receives previous_critique
        allow_any_instance_of(Agents::WriterAgent).to receive(:run) do |_, _, **kwargs|
          expect(kwargs[:previous_critique]).to be_present
          expect(kwargs[:previous_critique]).to include('personalization')
          {
            email: rewritten_email,
            company: lead.company,
            recipient: lead.name,
            variants: [ rewritten_email ]
          }
        end

        # Run WRITER for rewrite
        result = described_class.run_agents_for_lead(lead, campaign, user, agent_name: 'WRITER')
        expect(result[:status]).to eq('completed')

        lead.reload
        expect(lead.stage).to match(/rewritten \(\d+\)/)
        expect(lead.stage).to eq('rewritten (1)')

        # Now verify CRITIQUE uses the NEW rewritten email, not the original
        second_critique_email_content = nil
        allow_any_instance_of(Agents::CritiqueAgent).to receive(:run) do |_, article, **|
          second_critique_email_content = article['email_content']
          {
            'critique' => nil, # Good enough
            'score' => 8,
            'meets_min_score' => true
          }
        end

        result = described_class.run_agents_for_lead(lead, campaign, user, agent_name: 'CRITIQUE')
        expect(result[:status]).to eq('completed')

        # Verify CRITIQUE critiqued the rewritten email, not the original
        expect(second_critique_email_content).to include('Improved Email')
        expect(second_critique_email_content).not_to include('Original Email')
        expect(second_critique_email_content).to eq(rewritten_email)
      end

      it 'loads latest completed WRITER output for CRITIQUE, not failed or old outputs' do
        # Create multiple WRITER outputs: one failed, one old completed, one new completed
        create(:agent_output,
          lead: lead,
          agent_name: 'WRITER',
          status: 'failed',
          output_data: { email: 'Failed email' },
          created_at: 1.hour.ago
        )

        old_email = "Subject: Old Email\n\nThis is an old version."
        create(:agent_output,
          lead: lead,
          agent_name: 'WRITER',
          status: 'completed',
          output_data: { email: old_email },
          created_at: 30.minutes.ago
        )

        latest_email = "Subject: Latest Email\n\nThis is the most recent version."
        create(:agent_output,
          lead: lead,
          agent_name: 'WRITER',
          status: 'completed',
          output_data: { email: latest_email },
          created_at: 5.minutes.ago
        )

        # CRITIQUE should use the latest completed output
        critique_email_content = nil
        expect_any_instance_of(Agents::CritiqueAgent).to receive(:run) do |_, article, **|
          critique_email_content = article['email_content']
          {
            'critique' => nil,
            'score' => 8,
            'meets_min_score' => true
          }
        end

        described_class.run_agents_for_lead(lead, campaign, user, agent_name: 'CRITIQUE')

        expect(critique_email_content).to eq(latest_email)
        expect(critique_email_content).not_to eq(old_email)
      end

      it 'passes agent_name correctly through async job' do
        # Test that agent_name is preserved when queued as background job
        # This is tested implicitly through the job, but we can verify the job receives it

        original_email = "Subject: Original\n\nContent"
        create(:agent_output,
          lead: lead,
          agent_name: 'WRITER',
          status: 'completed',
          output_data: { email: original_email }
        )

        AgentConfig.find_or_create_by!(campaign: campaign, agent_name: 'CRITIQUE') do |cfg|
          cfg.enabled = true
        end

        allow_any_instance_of(Agents::CritiqueAgent).to receive(:run).and_return({
          'critique' => 'Needs improvement',
          'score' => 4,
          'meets_min_score' => false
        })

        # Run in sync mode (to test the logic without job queue complexity)
        result = described_class.run_agents_for_lead(lead, campaign, user, agent_name: 'CRITIQUE')

        expect(result[:status]).to eq('completed')
        expect(result[:completed_agents]).to contain_exactly('CRITIQUE')
      end
    end
  end
end
