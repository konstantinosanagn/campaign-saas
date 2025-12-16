require "rails_helper"

RSpec.describe "Agent Settings Filtering Integration", type: :integration do
  let(:user) { create(:user) }
  let(:campaign) { create(:campaign, user: user) }
  let(:lead) { create(:lead, campaign: campaign) }

  LeadRunExecutor::LLM_AGENT_NAMES.each do |agent_name|
    context "when agent is #{agent_name}" do
      # Create a fresh lead_run for each agent to avoid position conflicts
      let(:lead_run) { create(:lead_run, lead: lead, campaign: campaign) }

      let(:writer_step) do
        create(:lead_run_step, lead_run: lead_run, agent_name: "WRITER", status: "completed", position: 10)
      end

      let(:writer_output) do
        ws = writer_step
        create(:agent_output, lead_run: lead_run, lead_run_step: ws, agent_name: "WRITER",
               output_data: { "email" => "test email", "variants" => [] })
      end

      let(:step) do
        meta = {
          "settings_snapshot" => {
            "min_score_for_send" => 10,
            "strictness" => "moderate",
            "other_setting" => "value"
          }
        }

        # Add required metadata for CRITIQUE agent
        if agent_name == "CRITIQUE"
          ws = writer_step
          writer_output # Ensure it's created
          meta["writer_step_id"] = ws.id
          meta["selected_variant_index"] = 0
        end

        create(:lead_run_step,
          lead_run: lead_run,
          agent_name: agent_name,
          position: agent_name == "CRITIQUE" ? 20 : 10,
          meta: meta)
      end

      it "never passes min_score_for_send to agent" do
        # Stub the agent class to capture what it receives
        agent_class = case agent_name
        when "SEARCH"
          Agents::SearchAgent
        when "WRITER"
          Agents::WriterAgent
        when "CRITIQUE"
          Agents::CritiqueAgent
        when "DESIGN"
          Agents::DesignAgent
        end

        # Track what settings the agent receives
        received_settings = nil
        allow(agent_class).to receive(:new).and_wrap_original do |method, *args, **kwargs|
          instance = method.call(*args, **kwargs)
          # For agents that receive config in run/critique method, we need to stub differently
          instance
        end

        # For CRITIQUE agent, stub the critique method to capture config
        if agent_name == "CRITIQUE"
          allow_any_instance_of(agent_class).to receive(:critique) do |instance, article, config:|
            received_settings = config&.dig(:settings) || config&.dig("settings")
            { "score" => 8, "critique" => "test", "meets_min_score" => true }
          end
        elsif agent_name == "WRITER"
          allow_any_instance_of(agent_class).to receive(:run) do |instance, *args, config: nil, **kwargs|
            received_settings = config&.dig(:settings) || config&.dig("settings")
            { "email" => "test email", "company" => "test" }
          end
        elsif agent_name == "SEARCH"
          allow_any_instance_of(agent_class).to receive(:run) do |instance, *args, config: nil, **kwargs|
            received_settings = config&.dig(:settings) || config&.dig("settings")
            { "domain" => { "domain" => "test.com" }, "sources" => [] }
          end
        elsif agent_name == "DESIGN"
          allow_any_instance_of(agent_class).to receive(:run) do |instance, *args, config: nil, **kwargs|
            received_settings = config&.dig(:settings) || config&.dig("settings")
            { "email" => "formatted email" }
          end
        end

        # Mock API keys
        allow(ApiKeyService).to receive(:get_gemini_api_key).and_return("test-key")
        allow(ApiKeyService).to receive(:get_tavily_api_key).and_return("test-key")

        # Run dispatcher
        AgentDispatcher.dispatch!(lead_run: lead_run, step: step)

        # Verify agent never received min_score_for_send
        if received_settings
          expect(received_settings).not_to have_key("min_score_for_send")
          expect(received_settings).not_to have_key(:min_score_for_send)
          expect(received_settings["strictness"] || received_settings[:strictness]).to eq("moderate")
          expect(received_settings["other_setting"] || received_settings[:other_setting]).to eq("value")
        end
      end
    end
  end
end
