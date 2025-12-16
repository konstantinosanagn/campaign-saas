require "rails_helper"

RSpec.describe LeadRuns::PromptSettingsFilter do
  describe ".filter" do
    context "for LLM agents" do
      LeadRunExecutor::LLM_AGENT_NAMES.each do |agent_name|
        context "when agent is #{agent_name}" do
          it "strips min_score_for_send from top level" do
            settings = {
              "min_score_for_send" => 10,
              "strictness" => "moderate",
              "other_setting" => "value"
            }
            result = described_class.filter(agent_name: agent_name, settings: settings)
            expect(result).not_to have_key("min_score_for_send")
            expect(result).not_to have_key(:min_score_for_send)
            expect(result["strictness"]).to eq("moderate")
            expect(result["other_setting"]).to eq("value")
          end

          it "strips :min_score_for_send symbol key" do
            settings = {
              min_score_for_send: 10,
              strictness: "moderate"
            }
            result = described_class.filter(agent_name: agent_name, settings: settings)
            expect(result).not_to have_key("min_score_for_send")
            expect(result).not_to have_key(:min_score_for_send)
            expect(result[:strictness]).to eq("moderate")
          end

          it "strips nested occurrences recursively" do
            settings = {
              "checks" => {
                "check_personalization" => true,
                "min_score_for_send" => 10
              },
              "nested" => {
                "deep" => {
                  "min_score_for_send" => 10
                }
              }
            }
            result = described_class.filter(agent_name: agent_name, settings: settings)
            expect(result["checks"]).not_to have_key("min_score_for_send")
            expect(result["nested"]["deep"]).not_to have_key("min_score_for_send")
            expect(result["checks"]["check_personalization"]).to be true
          end

          it "handles arrays with nested hashes" do
            settings = {
              "items" => [
                { "name" => "item1", "min_score_for_send" => 10 },
                { "name" => "item2" }
              ]
            }
            result = described_class.filter(agent_name: agent_name, settings: settings)
            expect(result["items"][0]).not_to have_key("min_score_for_send")
            expect(result["items"][0]["name"]).to eq("item1")
            expect(result["items"][1]["name"]).to eq("item2")
          end

          it "does not mutate original object" do
            original = { "min_score_for_send" => 10, "strictness" => "moderate" }
            result = described_class.filter(agent_name: agent_name, settings: original)
            expect(original).to have_key("min_score_for_send")
            expect(result).not_to have_key("min_score_for_send")
          end

          it "normalizes keys to string for comparison" do
            # Test with symbol key
            settings = { min_score_for_send: 10 }
            result = described_class.filter(agent_name: agent_name, settings: settings)
            expect(result).not_to have_key(:min_score_for_send)
            expect(result).not_to have_key("min_score_for_send")
          end
        end
      end
    end

    context "for non-LLM agents" do
      it "returns unfiltered settings for SENDER" do
        settings = { "min_score_for_send" => 10, "other" => "value" }
        result = described_class.filter(agent_name: "SENDER", settings: settings)
        expect(result).to have_key("min_score_for_send")
        expect(result["min_score_for_send"]).to eq(10)
      end
    end

    context "edge cases" do
      it "handles nil settings" do
        result = described_class.filter(agent_name: "CRITIQUE", settings: nil)
        expect(result).to eq({})
      end

      it "handles empty hash" do
        result = described_class.filter(agent_name: "CRITIQUE", settings: {})
        expect(result).to eq({})
      end

      it "is idempotent" do
        settings = { "min_score_for_send" => 10, "strictness" => "moderate" }
        result1 = described_class.filter(agent_name: "CRITIQUE", settings: settings)
        result2 = described_class.filter(agent_name: "CRITIQUE", settings: result1)
        expect(result1).to eq(result2)
        expect(result2).not_to have_key("min_score_for_send")
      end
    end
  end
end
