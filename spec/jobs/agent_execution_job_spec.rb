require "rails_helper"

RSpec.describe AgentExecutionJob, type: :job do
  let(:lead_id) { 11 }
  let(:campaign_id) { 22 }
  let(:user_id) { 33 }

  let(:lead) { instance_double("Lead", id: lead_id, campaign_id: campaign_id) }
  let(:campaign) { instance_double("Campaign", id: campaign_id, user_id: user_id) }
  let(:user) { instance_double("User", id: user_id) }

  subject(:job_instance) { described_class.new }

  before do
    allow(Lead).to receive(:find_by).with(id: lead_id).and_return(lead)
    allow(Campaign).to receive(:find_by).with(id: campaign_id).and_return(campaign)
    allow(User).to receive(:find_by).with(id: user_id).and_return(user)
    allow(User).to receive(:find).with(user_id).and_return(user)

    allow(ApiKeyService).to receive(:get_gemini_api_key).with(user)
    allow(ApiKeyService).to receive(:get_tavily_api_key).with(user)
  end

  context "when campaign does not belong to the user" do
    it "logs an unauthorized access error and returns early" do
      bad_campaign = instance_double("Campaign", id: campaign_id, user_id: 999)
      allow(Campaign).to receive(:find_by).with(id: campaign_id).and_return(bad_campaign)

      logger = double("logger").as_null_object
      allow(Rails).to receive(:logger).and_return(logger)

      expect(logger).to receive(:error).with(/Unauthorized access attempt/)

      job_instance.perform(lead_id, campaign_id, user_id)

      # Ensure we never try to fetch API keys or run agents
      expect(ApiKeyService).not_to have_received(:get_gemini_api_key)
      expect(LeadAgentService).not_to receive(:run_agents_for_lead)
    end
  end

  context "when lead does not belong to campaign" do
    it "logs an error and returns early" do
      bad_lead = instance_double("Lead", id: lead_id, campaign_id: 999)
      allow(Lead).to receive(:find_by).with(id: lead_id).and_return(bad_lead)

      logger = double("logger").as_null_object
      allow(Rails).to receive(:logger).and_return(logger)

      expect(logger).to receive(:error).with(/Lead #{lead_id} does not belong to campaign #{campaign_id}/)

      job_instance.perform(lead_id, campaign_id, user_id)

      expect(ApiKeyService).not_to have_received(:get_gemini_api_key)
    end
  end

  context "when API keys are missing" do
    it "raises ArgumentError (discarded by ActiveJob)" do
      allow(ApiKeyService).to receive(:get_gemini_api_key).with(user).and_raise(ArgumentError, "missing key")

      expect {
        job_instance.perform(lead_id, campaign_id, user_id)
      }.to raise_error(ArgumentError, /missing key/)
    end
  end

  context "when LeadAgentService reports failure" do
    it "logs a warning with the error details" do
      result = { status: "failed", error: "something went wrong", completed_agents: 1, failed_agents: 2 }
      allow(LeadAgentService).to receive(:run_agents_for_lead).with(lead, campaign, user).and_return(result)

      logger = double("logger").as_null_object
      allow(Rails).to receive(:logger).and_return(logger)

      expect(logger).to receive(:warn).with(/Agent execution failed for lead #{lead_id}: #{result[:error]}/)

      job_instance.perform(lead_id, campaign_id, user_id)
    end
  end

  context "when LeadAgentService reports success" do
    it "logs an info message with completed/failed counts" do
      result = { status: "ok", completed_agents: 3, failed_agents: 0 }
      allow(LeadAgentService).to receive(:run_agents_for_lead).with(lead, campaign, user).and_return(result)

      logger = double("logger").as_null_object
      allow(Rails).to receive(:logger).and_return(logger)

      expect(logger).to receive(:info).with(/Successfully executed agents for lead #{lead_id}. Completed: #{result[:completed_agents]}, Failed: #{result[:failed_agents]}/)

      job_instance.perform(lead_id, campaign_id, user_id)
    end
  end

  context "when LeadAgentService raises unexpected error" do
    it "logs the error and re-raises to trigger retries" do
      err = RuntimeError.new("encounter error")
      allow(LeadAgentService).to receive(:run_agents_for_lead).and_raise(err)

      logger = double("logger")
      allow(Rails).to receive(:logger).and_return(logger)

      expect(logger).to receive(:error).with(/Unexpected error processing lead #{lead_id}: #{err.class} - #{err.message}/)
      expect(logger).to receive(:error).with(a_string_including("/"))

      expect {
        job_instance.perform(lead_id, campaign_id, user_id)
      }.to raise_error(RuntimeError, /encounter error/)
    end
  end
end
