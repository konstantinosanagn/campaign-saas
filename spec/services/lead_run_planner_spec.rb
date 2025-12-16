require "rails_helper"

RSpec.describe LeadRunPlanner, type: :service do
  let(:user) { create(:user) }
  let(:campaign) { create(:campaign, user: user) }
  let(:lead) { create(:lead, campaign: campaign) }

  before do
    # Ensure deterministic defaults exist for core agents.
    LeadAgentService::ConfigManager.get_agent_config(campaign, AgentConstants::AGENT_SEARCH)
    LeadAgentService::ConfigManager.get_agent_config(campaign, AgentConstants::AGENT_WRITER)
    LeadAgentService::ConfigManager.get_agent_config(campaign, AgentConstants::AGENT_CRITIQUE)
    LeadAgentService::ConfigManager.get_agent_config(campaign, AgentConstants::AGENT_DESIGN)
  end

  it "creates a lead_run and lead_run_steps in fixed order (excluding SENDER by default)" do
    run = described_class.build!(lead: lead)

    expect(run).to be_persisted
    expect(run.steps.pluck(:agent_name)).to eq(%w[SEARCH WRITER CRITIQUE DESIGN])
  end

  it "writes CRITIQUE meta linkage to the preceding WRITER step" do
    run = described_class.build!(lead: lead)
    writer = run.steps.find { |s| s.agent_name == "WRITER" }
    critique = run.steps.find { |s| s.agent_name == "CRITIQUE" }

    expect(critique.meta["writer_step_id"]).to eq(writer.id)
    expect(critique.meta["selected_variant_index"]).to eq(0)
  end

  it "sets lead.current_lead_run_id" do
    run = described_class.build!(lead: lead)
    lead.reload
    expect(lead.current_lead_run_id).to eq(run.id)
  end

  context "when AgentConfig has min_score_for_send: 10" do
    before do
      agent_config = LeadAgentService::ConfigManager.get_agent_config(campaign, AgentConstants::AGENT_CRITIQUE)
      agent_config.update!(settings: { "min_score_for_send" => 10, "strictness" => "moderate" })
    end

    it "stores min_score as 10 (not clamped)" do
      run = described_class.build!(lead: lead)
      expect(run.min_score).to eq(10)
    end

    it "stores 10 in config_snapshot for audit" do
      run = described_class.build!(lead: lead)
      critique_settings = run.config_snapshot.dig("agents", "CRITIQUE", "settings")
      expect(critique_settings["min_score_for_send"]).to eq(10)
    end
  end

  context "derived_min_score" do
    it "can return 10" do
      agent_config = LeadAgentService::ConfigManager.get_agent_config(campaign, AgentConstants::AGENT_CRITIQUE)
      agent_config.update!(settings: { "min_score_for_send" => 10 })

      run = described_class.build!(lead: lead)
      expect(run.min_score).to eq(10)
    end

    it "uses ConfigResolver.resolve output" do
      agent_config = LeadAgentService::ConfigManager.get_agent_config(campaign, AgentConstants::AGENT_CRITIQUE)
      agent_config.update!(settings: { "min_score_for_send" => 8 })

      # Verify it uses the resolver (which should return the value from config)
      run = described_class.build!(lead: lead)
      expect(run.min_score).to eq(8)
    end
  end

  context "SENDER agent inclusion (Phase 9.1)" do
    let!(:writer_step) do
      run = create(:lead_run, lead: lead, campaign: campaign, status: 'completed')
      step = create(:lead_run_step, lead_run: run, agent_name: AgentConstants::AGENT_WRITER, status: 'completed', position: 20)
      create(:agent_output, lead: lead, lead_run: run, lead_run_step: step, agent_name: AgentConstants::AGENT_WRITER, status: 'completed', output_data: { 'email' => 'Test email' })
      step
    end

    context "when SENDER is enabled and sending is configured" do
      before do
        create(:agent_config, campaign: campaign, agent_name: AgentConstants::AGENT_SENDER, enabled: true)
        user.update!(gmail_access_token: 'token', gmail_refresh_token: 'refresh', gmail_email: 'test@gmail.com')
      end

      it "includes SENDER in the plan with source_step_id meta" do
        run = described_class.build!(lead: lead)

        sender_step = run.steps.find { |s| s.agent_name == AgentConstants::AGENT_SENDER }
        expect(sender_step).to be_present
        expect(sender_step.meta['source_step_id']).to be_present

        # Source should be DESIGN if available, else WRITER
        design_step = run.steps.find { |s| s.agent_name == AgentConstants::AGENT_DESIGN }
        expected_source_id = design_step ? design_step.id : writer_step.id
        expect(sender_step.meta['source_step_id']).to eq(expected_source_id)
      end

      it "includes SENDER in plan steps" do
        run = described_class.build!(lead: lead)
        plan_steps = run.plan['steps'].map { |s| s['agent_name'] }
        expect(plan_steps).to include(AgentConstants::AGENT_SENDER)
      end
    end

    context "when SENDER is enabled but sending is not configured" do
      before do
        create(:agent_config, campaign: campaign, agent_name: AgentConstants::AGENT_SENDER, enabled: true)
        # Don't configure Gmail or SMTP
        user.update!(gmail_access_token: nil, gmail_refresh_token: nil, gmail_email: nil)
        allow(ENV).to receive(:[]).with('DEFAULT_GMAIL_SENDER').and_return(nil)
        allow(ENV).to receive(:[]).with('SMTP_ADDRESS').and_return(nil)
        allow(ENV).to receive(:[]).with('SMTP_PASSWORD').and_return(nil)
      end

      it "raises PlannerError with sending_not_configured and machine-readable reasons" do
        expect {
          described_class.build!(lead: lead)
        }.to raise_error(LeadRunPlanner::PlannerError, 'sending_not_configured')
      end
    end

    context "when SENDER config is missing" do
      it "excludes SENDER from the plan" do
        run = described_class.build!(lead: lead)
        sender_step = run.steps.find { |s| s.agent_name == AgentConstants::AGENT_SENDER }
        expect(sender_step).to be_nil
        expect(run.steps.pluck(:agent_name)).not_to include(AgentConstants::AGENT_SENDER)
      end
    end

    context "when SENDER config is disabled" do
      before do
        create(:agent_config, campaign: campaign, agent_name: AgentConstants::AGENT_SENDER, enabled: false)
      end

      it "excludes SENDER from the plan" do
        run = described_class.build!(lead: lead)
        sender_step = run.steps.find { |s| s.agent_name == AgentConstants::AGENT_SENDER }
        expect(sender_step).to be_nil
      end
    end
  end
end
