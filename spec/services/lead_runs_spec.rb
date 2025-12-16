require "rails_helper"

RSpec.describe LeadRuns, type: :service do
  describe ".status_payload_for" do
    it "returns a stable no-run payload when no active run exists" do
      user = create(:user)
      campaign = create(:campaign, user: user)
      lead = create(:lead, campaign: campaign)

      payload = described_class.status_payload_for(lead)

      expect(payload).to include(
        run_id: nil,
        run_status: "none",
        running_step: nil,
        last_completed_step: nil,
        next_step: nil,
        rewrite_count: 0,
        can_send: false
      )
    end

    it "never writes to the database (read-only tripwire)" do
      user = create(:user)
      campaign = create(:campaign, user: user)
      lead = create(:lead, campaign: campaign)

      # Create some existing data to ensure we're not just testing empty state
      AgentConfig.create!(campaign: campaign, agent_name: "SEARCH", enabled: true, settings: {})
      run = LeadRunPlanner.build!(lead: lead)

      expect {
        described_class.status_payload_for(lead)
      }.not_to change {
        [
          LeadRun.count,
          LeadRunStep.count,
          AgentConfig.count,
          AgentOutput.count
        ]
      }
    end
  end

  describe ".reconcile_disabled_steps!" do
    it "marks queued steps as skipped with meta recorded when agent is disabled" do
      user = create(:user)
      campaign = create(:campaign, user: user)
      lead = create(:lead, campaign: campaign)
      run = create(:lead_run, lead: lead, campaign: campaign, status: "queued")

      # Create queued DESIGN step
      design_step = create(:lead_run_step, lead_run: run, agent_name: "DESIGN", status: "queued", position: 10, meta: {})

      # Create disabled DESIGN agent config
      create(:agent_config, campaign: campaign, agent_name: "DESIGN", enabled: false, settings: {})

      described_class.reconcile_disabled_steps!(run, campaign)

      design_step.reload
      expect(design_step.status).to eq("skipped")
      expect(design_step.meta["skip_reason"]).to eq("disabled")
      expect(design_step.step_finished_at).to be_present
    end
  end

  describe ".reconcile_enabled_steps!" do
    it "only requeues disabled-skipped steps, not other skipped steps" do
      user = create(:user)
      campaign = create(:campaign, user: user)
      lead = create(:lead, campaign: campaign)
      run = create(:lead_run, lead: lead, campaign: campaign, status: "queued")

      # Create two skipped steps with different skip reasons
      design_step = create(:lead_run_step, lead_run: run, agent_name: "DESIGN", status: "skipped", position: 10, meta: { "skip_reason" => "disabled" })
      writer_step = create(:lead_run_step, lead_run: run, agent_name: "WRITER", status: "skipped", position: 20, meta: { "skip_reason" => "other_reason" })

      # Enable DESIGN agent config
      create(:agent_config, campaign: campaign, agent_name: "DESIGN", enabled: true, settings: {})

      described_class.reconcile_enabled_steps!(run, campaign)

      design_step.reload
      writer_step.reload

      expect(design_step.status).to eq("queued")
      expect(design_step.meta["skip_reason"]).to be_nil
      expect(design_step.step_started_at).to be_nil
      expect(design_step.step_finished_at).to be_nil

      expect(writer_step.status).to eq("skipped")
      expect(writer_step.meta["skip_reason"]).to eq("other_reason")
    end
  end

  describe ".ensure_design_step!" do
    it "inserts DESIGN before queued SENDER with correct positioning" do
      user = create(:user)
      campaign = create(:campaign, user: user)
      lead = create(:lead, campaign: campaign)
      run = create(:lead_run, lead: lead, campaign: campaign, status: "queued")

      # Create steps: CRITIQUE at position 20, SENDER at position 30
      create(:lead_run_step, lead_run: run, agent_name: "CRITIQUE", status: "queued", position: 20, meta: {})
      sender_step = create(:lead_run_step, lead_run: run, agent_name: "SENDER", status: "queued", position: 30, meta: {})

      described_class.ensure_design_step!(run)

      design_step = run.steps.find_by(agent_name: "DESIGN")
      expect(design_step).to be_present
      expect(design_step.status).to eq("queued")
      expect(design_step.position).to eq(29) # Right before SENDER

      # Verify ordering
      steps = run.steps.order(:position)
      expect(steps.map(&:agent_name)).to eq([ "CRITIQUE", "DESIGN", "SENDER" ])
    end

    it "does not create duplicate DESIGN steps" do
      user = create(:user)
      campaign = create(:campaign, user: user)
      lead = create(:lead, campaign: campaign)
      run = create(:lead_run, lead: lead, campaign: campaign, status: "queued")

      # Create existing DESIGN step (any status)
      existing_design = create(:lead_run_step, lead_run: run, agent_name: "DESIGN", status: "completed", position: 10, meta: {})

      # Call ensure_design_step! twice
      described_class.ensure_design_step!(run)
      described_class.ensure_design_step!(run)

      design_steps = run.steps.where(agent_name: "DESIGN")
      expect(design_steps.count).to eq(1)
      expect(design_steps.first.id).to eq(existing_design.id)
    end

    it "triggers resequencing when position conflict occurs" do
      user = create(:user)
      campaign = create(:campaign, user: user)
      lead = create(:lead, campaign: campaign)
      run = create(:lead_run, lead: lead, campaign: campaign, status: "queued")

      # Create step at position 19, SENDER at position 20
      create(:lead_run_step, lead_run: run, agent_name: "CRITIQUE", status: "queued", position: 19, meta: {})
      sender_step = create(:lead_run_step, lead_run: run, agent_name: "SENDER", status: "queued", position: 20, meta: {})

      described_class.ensure_design_step!(run)

      # Should resequence to create gaps (10, 20, 30...)
      design_step = run.steps.find_by(agent_name: "DESIGN")
      expect(design_step).to be_present

      # Verify positions are resequenced
      steps = run.steps.order(:position)
      positions = steps.pluck(:position)
      expect(positions).to all(be_a(Integer))
      expect(positions).to all(be > 0)
      # DESIGN should be before SENDER
      design_pos = design_step.position
      sender_pos = sender_step.reload.position
      expect(design_pos).to be < sender_pos
    end

    it "handles position <= 1 by resequencing first" do
      user = create(:user)
      campaign = create(:campaign, user: user)
      lead = create(:lead, campaign: campaign)
      run = create(:lead_run, lead: lead, campaign: campaign, status: "queued")

      # Create SENDER at position 1
      sender_step = create(:lead_run_step, lead_run: run, agent_name: "SENDER", status: "queued", position: 1, meta: {})

      described_class.ensure_design_step!(run)

      # Should resequence first, then insert
      design_step = run.steps.find_by(agent_name: "DESIGN")
      expect(design_step).to be_present

      # Verify positions are resequenced (should be 10, 20, etc.)
      steps = run.steps.order(:position)
      positions = steps.pluck(:position)
      expect(positions.min).to be >= 10
    end

    it "does not insert if SENDER already finished" do
      user = create(:user)
      campaign = create(:campaign, user: user)
      lead = create(:lead, campaign: campaign)
      run = create(:lead_run, lead: lead, campaign: campaign, status: "queued")

      # Create SENDER with completed status
      create(:lead_run_step, lead_run: run, agent_name: "SENDER", status: "completed", position: 10, meta: {})

      described_class.ensure_design_step!(run)

      design_step = run.steps.find_by(agent_name: "DESIGN")
      expect(design_step).to be_nil
    end
  end

  describe ".reconcile_disabled_steps! with non-PostgreSQL adapter" do
    it "works with Ruby-side updates when adapter is not PostgreSQL" do
      user = create(:user)
      campaign = create(:campaign, user: user)
      lead = create(:lead, campaign: campaign)
      run = create(:lead_run, lead: lead, campaign: campaign, status: "queued")

      design_step = create(:lead_run_step, lead_run: run, agent_name: "DESIGN", status: "queued", position: 10, meta: {})
      create(:agent_config, campaign: campaign, agent_name: "DESIGN", enabled: false, settings: {})

      # Stub adapter to return non-PostgreSQL
      allow(ActiveRecord::Base.connection).to receive(:adapter_name).and_return("SQLite")

      described_class.reconcile_disabled_steps!(run, campaign)

      design_step.reload
      expect(design_step.status).to eq("skipped")
      expect(design_step.meta["skip_reason"]).to eq("disabled")
    end
  end

  describe ".reconcile_enabled_steps! with non-PostgreSQL adapter" do
    it "works with Ruby-side updates when adapter is not PostgreSQL" do
      user = create(:user)
      campaign = create(:campaign, user: user)
      lead = create(:lead, campaign: campaign)
      run = create(:lead_run, lead: lead, campaign: campaign, status: "queued")

      design_step = create(:lead_run_step, lead_run: run, agent_name: "DESIGN", status: "skipped", position: 10, meta: { "skip_reason" => "disabled" })
      create(:agent_config, campaign: campaign, agent_name: "DESIGN", enabled: true, settings: {})

      # Stub adapter to return non-PostgreSQL
      allow(ActiveRecord::Base.connection).to receive(:adapter_name).and_return("SQLite")

      described_class.reconcile_enabled_steps!(run, campaign)

      design_step.reload
      expect(design_step.status).to eq("queued")
      expect(design_step.meta["skip_reason"]).to be_nil
    end
  end
end
