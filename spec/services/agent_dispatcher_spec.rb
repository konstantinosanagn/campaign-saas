require "rails_helper"

RSpec.describe AgentDispatcher do
  let(:user) { create(:user) }
  let(:campaign) { create(:campaign, user: user) }
  let(:lead) { create(:lead, campaign: campaign) }
  let(:lead_run) { create(:lead_run, lead: lead, campaign: campaign) }
  let(:step) { create(:lead_run_step, lead_run: lead_run, agent_name: agent_name, meta: step_meta) }

  describe "#settings_for" do
    LeadRunExecutor::LLM_AGENT_NAMES.each do |agent_name|
      context "when agent is #{agent_name}" do
        let(:agent_name) { agent_name }

        context "with settings from step.meta" do
          let(:step_meta) do
            {
              "settings_snapshot" => {
                "min_score_for_send" => 10,
                "strictness" => "moderate",
                "other_setting" => "value"
              }
            }
          end

          it "returns settings without min_score_for_send" do
            dispatcher = described_class.new(lead_run: lead_run, step: step)
            result = dispatcher.send(:settings_for, agent_name)

            expect(result).not_to have_key("min_score_for_send")
            expect(result).not_to have_key(:min_score_for_send)
            expect(result["strictness"] || result[:strictness]).to eq("moderate")
            expect(result["other_setting"] || result[:other_setting]).to eq("value")
          end
        end

        context "with settings from ConfigResolver fallback" do
          let(:step_meta) { {} }
          let(:agent_config) { create(:agent_config, campaign: campaign, agent_name: agent_name, settings: { "min_score_for_send" => 10, "strictness" => "moderate" }) }

          before do
            allow(LeadRuns::ConfigResolver).to receive(:resolve).and_return({
              enabled: true,
              settings_snapshot: {
                "min_score_for_send" => 10,
                "strictness" => "moderate"
              }
            })
          end

          it "returns filtered settings without min_score_for_send" do
            dispatcher = described_class.new(lead_run: lead_run, step: step)
            result = dispatcher.send(:settings_for, agent_name)

            expect(result).not_to have_key("min_score_for_send")
            expect(result).not_to have_key(:min_score_for_send)
            expect(result["strictness"] || result[:strictness]).to eq("moderate")
          end
        end

        context "with symbol keys in settings_snapshot" do
          let(:step_meta) do
            {
              settings_snapshot: {
                min_score_for_send: 10,
                strictness: "moderate"
              }
            }
          end

          it "strips min_score_for_send regardless of key type" do
            dispatcher = described_class.new(lead_run: lead_run, step: step)
            result = dispatcher.send(:settings_for, agent_name)

            expect(result).not_to have_key("min_score_for_send")
            expect(result).not_to have_key(:min_score_for_send)
          end
        end
      end
    end

    context "when agent is SENDER (non-LLM)" do
      let(:agent_name) { "SENDER" }
      let(:step_meta) do
        {
          "settings_snapshot" => {
            "min_score_for_send" => 10,
            "other" => "value"
          }
        }
      end

      it "does not filter min_score_for_send" do
        dispatcher = described_class.new(lead_run: lead_run, step: step)
        result = dispatcher.send(:settings_for, agent_name)

        # SENDER is not an LLM agent, so filter should not apply
        # But since we're testing the filter behavior, let's verify it's present
        expect(result["min_score_for_send"] || result[:min_score_for_send]).to eq(10)
      end
    end
  end
end
