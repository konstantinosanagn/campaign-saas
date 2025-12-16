require "rails_helper"

RSpec.describe AgentExecutionJob, type: :job do
  let(:user) { create(:user, llm_api_key: "test-llm-key", tavily_api_key: "test-tavily-key") }
  let(:campaign) { create(:campaign, user: user) }
  let(:lead) { create(:lead, campaign: campaign) }

  around do |example|
    old = ENV["AGENT_EXECUTION_PAUSED"]
    ENV["AGENT_EXECUTION_PAUSED"] = "false"
    example.run
  ensure
    ENV["AGENT_EXECUTION_PAUSED"] = old
  end

  describe "#perform" do
    it "rejects the removed legacy signature" do
      expect(LeadRunExecutor).not_to receive(:run_next!)

      begin
        described_class.perform_now(lead.id)
      rescue ArgumentError
        # discard_on ArgumentError may or may not re-raise in perform_now
      end
    end

    it "requires lead_run_id" do
      expect(LeadRunExecutor).not_to receive(:run_next!)

      begin
        described_class.perform_now({})
      rescue ArgumentError
        # discard_on ArgumentError may or may not re-raise in perform_now
      end
    end

    it "runs the executor for the lead run" do
      run = LeadRunPlanner.build!(lead: lead)

      expect(LeadRunExecutor).to receive(:run_next!).with(lead_run_id: run.id, requested_agent_name: nil)
      described_class.perform_now({ lead_run_id: run.id })
    end

    it "passes requested_agent_name through" do
      run = LeadRunPlanner.build!(lead: lead)

      expect(LeadRunExecutor).to receive(:run_next!).with(lead_run_id: run.id, requested_agent_name: "WRITER")
      described_class.perform_now({ lead_run_id: run.id, requested_agent_name: "WRITER" })
    end

    it "does not execute when paused (retries later)" do
      run = LeadRunPlanner.build!(lead: lead)
      ENV["AGENT_EXECUTION_PAUSED"] = "true"

      step = run.steps.order(:position).first
      expect(step.status).to eq("queued")

      expect(LeadRunExecutor).not_to receive(:run_next!)
      begin
        described_class.perform_now({ lead_run_id: run.id })
      rescue AgentExecution::ExecutionPausedError
        # retry_on may re-raise or may enqueue a retry depending on adapter/runtime
      end

      step.reload
      expect(step.status).to eq("queued")
    end
  end
end
