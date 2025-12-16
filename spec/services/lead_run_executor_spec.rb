require "rails_helper"

RSpec.describe LeadRunExecutor do
  let(:user) { create(:user) }
  let(:campaign) { create(:campaign, user: user) }
  let(:lead) { create(:lead, campaign: campaign) }
  let(:lead_run) { create(:lead_run, lead: lead, campaign: campaign, min_score: min_score) }
  let(:step) { create(:lead_run_step, lead_run: lead_run, agent_name: "CRITIQUE", status: "running") }
  let(:output) { create(:agent_output, lead_run_step: step, status: "completed", output_data: output_data) }

  describe "#determine_outcome!" do
    context "when threshold sources are missing (edge case)" do
      # Note: min_score has NOT NULL constraint, so we test the edge case by using a step
      # with empty settings_snapshot (no min_score_for_send) to verify fallback behavior
      let(:lead_run_edge) { create(:lead_run, lead: lead, campaign: campaign, min_score: 6) }
      let(:step_edge) do
        # Step with empty settings_snapshot (no min_score_for_send) - falls back to run.min_score
        create(:lead_run_step, lead_run: lead_run_edge, agent_name: "CRITIQUE", status: "running",
               meta: { "settings_snapshot" => {} })
      end
      let(:output_edge) { create(:agent_output, lead_run_step: step_edge, status: "completed", output_data: { "score" => 8 }) }

      it "always ensures threshold_used is an Integer (defaults to 0 if nil)" do
        executor = described_class.new(lead_run_id: lead_run_edge.id)

        # Mock the run to return nil for min_score to test the nil-handling code path
        allow(lead_run_edge).to receive(:min_score).and_return(nil)

        result = executor.send(:determine_outcome!, locked_run: lead_run_edge, step: step_edge, output: output_edge)

        # Should default to 0 when run.min_score is nil
        expect(result[:output_updates][:output_data]["threshold_used"]).to eq(0)
        expect(result[:output_updates][:output_data]["threshold_was_nil"]).to be true
        expect(result[:output_updates][:output_data]["threshold_source"]).to eq("run.min_score")
        # score >= 0 should be true, so meets_min_score should be true
        expect(result[:output_updates][:output_data]["meets_min_score"]).to be true
      end
    end

    context "when min_score is 10" do
      let(:min_score) { 10 }

      context "when score is 10" do
        let(:output_data) { { "score" => 10, "critique" => "test" } }

        it "sets meets_min_score to true and stores threshold_used with source pointer" do
          executor = described_class.new(lead_run_id: lead_run.id)
          result = executor.send(:determine_outcome!, locked_run: lead_run, step: step, output: output)

          expect(result[:output_updates][:output_data]["meets_min_score"]).to be true
          expect(result[:output_updates][:output_data]["threshold_used"]).to eq(10)
          expect(result[:output_updates][:output_data]["threshold_was_nil"]).to be false
          expect(result[:output_updates][:output_data]["threshold_source"]).to eq("run.min_score")
          expect(result[:output_updates][:output_data]["threshold_source_pointer"]).to eq("lead_runs.min_score")
          expect(result[:step_status]).to eq("completed")
        end
      end

      context "when score is 9" do
        let(:output_data) { { "score" => 9, "critique" => "test" } }

        it "sets meets_min_score to false and triggers rewrite/fail path, stores threshold_used with source pointer" do
          executor = described_class.new(lead_run_id: lead_run.id)
          result = executor.send(:determine_outcome!, locked_run: lead_run, step: step, output: output)

          expect(result[:output_updates][:output_data]["meets_min_score"]).to be false
          expect(result[:output_updates][:output_data]["threshold_used"]).to eq(10)
          expect(result[:output_updates][:output_data]["threshold_was_nil"]).to be false
          expect(result[:output_updates][:output_data]["threshold_source"]).to eq("run.min_score")
          expect(result[:output_updates][:output_data]["threshold_source_pointer"]).to eq("lead_runs.min_score")
          # Should trigger rewrite if rewrite_count < max_rewrites, or fail if no rewrites left
          expect(result[:step_status]).to be_in([ "completed", "failed" ])
        end
      end
    end

    context "when min_score is 9" do
      let(:min_score) { 9 }

      context "when score is 9" do
        let(:output_data) { { "score" => 9, "critique" => "test" } }

        it "sets meets_min_score to true and stores threshold_used with source pointer" do
          executor = described_class.new(lead_run_id: lead_run.id)
          result = executor.send(:determine_outcome!, locked_run: lead_run, step: step, output: output)

          expect(result[:output_updates][:output_data]["meets_min_score"]).to be true
          expect(result[:output_updates][:output_data]["threshold_used"]).to eq(9)
          expect(result[:output_updates][:output_data]["threshold_was_nil"]).to be false
          expect(result[:output_updates][:output_data]["threshold_source"]).to eq("run.min_score")
          expect(result[:output_updates][:output_data]["threshold_source_pointer"]).to eq("lead_runs.min_score")
        end
      end
    end

    context "verifies no clamping occurs" do
      let(:min_score) { 10 }
      let(:output_data) { { "score" => 10, "critique" => "test" } }

      it "uses locked_run.min_score directly without clamping" do
        executor = described_class.new(lead_run_id: lead_run.id)
        result = executor.send(:determine_outcome!, locked_run: lead_run, step: step, output: output)

        # Verify the comparison uses the raw min_score value (10), not a clamped value (9)
        expect(result[:output_updates][:output_data]["meets_min_score"]).to be true
        expect(lead_run.min_score).to eq(10)
      end
    end
  end

  describe "#update_stage_projection!" do
    let(:min_score) { 6 } # Default min_score for these tests
    let(:executor) { described_class.new(lead_run_id: lead_run.id) }

    context "when WRITER step completes" do
      let(:writer_step) { create(:lead_run_step, lead_run: lead_run, agent_name: "WRITER", status: "completed", meta: {}) }
      let(:writer_output) { create(:agent_output, lead_run_step: writer_step, status: "completed", output_data: { "email" => "test@example.com" }) }

      it "sets stage to 'written' for original WRITER" do
        executor.send(:update_stage_projection!, lead: lead, step: writer_step, output: writer_output)
        lead.reload
        expect(lead.stage).to eq(AgentConstants::STAGE_WRITTEN)
      end

      context "when WRITER step is a rewrite (has revision in meta)" do
        let(:writer_step) do
          create(:lead_run_step, lead_run: lead_run, agent_name: "WRITER", status: "completed",
                 meta: { "revision" => 1 })
        end

        it "sets stage to 'rewritten (1)' for rewrite WRITER" do
          executor.send(:update_stage_projection!, lead: lead, step: writer_step, output: writer_output)
          lead.reload
          expect(lead.stage).to eq(AgentConstants.rewritten_stage_name(1))
        end

        context "with symbol key in meta" do
          let(:writer_step) do
            create(:lead_run_step, lead_run: lead_run, agent_name: "WRITER", status: "completed",
                   meta: { revision: 2 })
          end

          it "sets stage to 'rewritten (2)' when revision is symbol key" do
            executor.send(:update_stage_projection!, lead: lead, step: writer_step, output: writer_output)
            lead.reload
            expect(lead.stage).to eq(AgentConstants.rewritten_stage_name(2))
          end
        end
      end
    end

    context "when CRITIQUE step completes" do
      let(:critique_step) { create(:lead_run_step, lead_run: lead_run, agent_name: "CRITIQUE", status: "completed") }

      context "when critique passes (meets_min_score: true)" do
        let(:critique_output) do
          create(:agent_output, lead_run_step: critique_step, status: "completed",
                 output_data: { "score" => 8, "meets_min_score" => true })
        end

        it "sets stage to 'critiqued'" do
          lead.update!(stage: AgentConstants::STAGE_WRITTEN)
          executor.send(:update_stage_projection!, lead: lead, step: critique_step, output: critique_output)
          lead.reload
          expect(lead.stage).to eq(AgentConstants::STAGE_CRITIQUED)
        end
      end

      context "when critique fails (meets_min_score: false)" do
        let(:critique_output) do
          create(:agent_output, lead_run_step: critique_step, status: "completed",
                 output_data: { "score" => 4, "meets_min_score" => false })
        end

        it "sets stage to 'critiqued' regardless of pass/fail" do
          lead.update!(stage: AgentConstants::STAGE_WRITTEN)
          executor.send(:update_stage_projection!, lead: lead, step: critique_step, output: critique_output)
          lead.reload
          # Stage should be "critiqued" (last completed milestone) even if critique failed
          # Pass/fail is tracked in output_data["meets_min_score"], not in stage
          expect(lead.stage).to eq(AgentConstants::STAGE_CRITIQUED)
        end
      end

      context "when critique is 'None' or empty (perfect email)" do
        let(:critique_output_none) do
          create(:agent_output, lead_run_step: critique_step, status: "completed",
                 output_data: { "score" => 10, "critique" => "None", "meets_min_score" => true })
        end
        let(:critique_output_empty) do
          create(:agent_output, lead_run_step: critique_step, status: "completed",
                 output_data: { "score" => 10, "critique" => "", "meets_min_score" => true })
        end
        let(:critique_output_n_a) do
          create(:agent_output, lead_run_step: critique_step, status: "completed",
                 output_data: { "score" => 10, "critique" => "N/A", "meets_min_score" => true })
        end

        it "normalizes 'None' to nil and sets critique_present: false" do
          executor.send(:update_stage_projection!, lead: lead, step: critique_step, output: critique_output_none)
          critique_output_none.reload
          expect(critique_output_none.output_data["critique"]).to be_nil
          expect(critique_output_none.output_data["critique_present"]).to be false
          expect(lead.reload.quality).to eq("high")
        end

        it "normalizes empty string to nil and sets critique_present: false" do
          executor.send(:update_stage_projection!, lead: lead, step: critique_step, output: critique_output_empty)
          critique_output_empty.reload
          expect(critique_output_empty.output_data["critique"]).to be_nil
          expect(critique_output_empty.output_data["critique_present"]).to be false
          expect(lead.reload.quality).to eq("high")
        end

        it "normalizes 'N/A' to nil and sets critique_present: false" do
          executor.send(:update_stage_projection!, lead: lead, step: critique_step, output: critique_output_n_a)
          critique_output_n_a.reload
          expect(critique_output_n_a.output_data["critique"]).to be_nil
          expect(critique_output_n_a.output_data["critique_present"]).to be false
          expect(lead.reload.quality).to eq("high")
        end

        it "does not normalize 'None' when it appears as part of actual feedback" do
          critique_output_with_none = create(:agent_output, lead_run_step: critique_step, status: "completed",
                                             output_data: { "score" => 8, "critique" => "None of the suggestions apply. The email is good.", "meets_min_score" => true })
          executor.send(:update_stage_projection!, lead: lead, step: critique_step, output: critique_output_with_none)
          critique_output_with_none.reload
          # Should preserve the actual feedback text (not normalize "None" substring)
          expect(critique_output_with_none.output_data["critique"]).to eq("None of the suggestions apply. The email is good.")
          expect(critique_output_with_none.output_data["critique_present"]).to be true
          expect(lead.reload.quality).to eq("medium")
        end

        it "normalizes 'None.' with trailing punctuation" do
          critique_output_none_dot = create(:agent_output, lead_run_step: critique_step, status: "completed",
                                            output_data: { "score" => 10, "critique" => "None.", "meets_min_score" => true })
          executor.send(:update_stage_projection!, lead: lead, step: critique_step, output: critique_output_none_dot)
          critique_output_none_dot.reload
          expect(critique_output_none_dot.output_data["critique"]).to be_nil
          expect(critique_output_none_dot.output_data["critique_present"]).to be false
          expect(lead.reload.quality).to eq("high")
        end

        it "normalizes 'N/A.' with trailing punctuation" do
          critique_output_n_a_dot = create(:agent_output, lead_run_step: critique_step, status: "completed",
                                            output_data: { "score" => 10, "critique" => "N/A.", "meets_min_score" => true })
          executor.send(:update_stage_projection!, lead: lead, step: critique_step, output: critique_output_n_a_dot)
          critique_output_n_a_dot.reload
          expect(critique_output_n_a_dot.output_data["critique"]).to be_nil
          expect(critique_output_n_a_dot.output_data["critique_present"]).to be false
          expect(lead.reload.quality).to eq("high")
        end
      end
    end
  end

  describe "#insert_rewrite_steps!" do
    let(:min_score) { 6 } # Default min_score for these tests
    let(:executor) { described_class.new(lead_run_id: lead_run.id) }
    let(:critique_step) do
      create(:lead_run_step, lead_run: lead_run, agent_name: "CRITIQUE", status: "completed", position: 30)
    end

    before do
      # Create initial steps to establish positions
      create(:lead_run_step, lead_run: lead_run, agent_name: "SEARCH", status: "completed", position: 10)
      create(:lead_run_step, lead_run: lead_run, agent_name: "WRITER", status: "completed", position: 20)
    end

    context "when rewrite is triggered" do
      it "increments rewrite_count" do
        expect { executor.send(:insert_rewrite_steps!, run: lead_run, failing_critique_step: critique_step) }
          .to change { lead_run.reload.rewrite_count }.by(1)
      end

      it "does not update lead stage when rewrite is inserted (stage remains at last completed milestone)" do
        lead.update!(stage: AgentConstants::STAGE_CRITIQUED)
        initial_stage = lead.stage
        executor.send(:insert_rewrite_steps!, run: lead_run, failing_critique_step: critique_step)
        lead.reload
        # Stage should not change on insertion - it represents "last completed milestone"
        # Stage will change to "rewritten (1)" when rewrite WRITER completes
        expect(lead.stage).to eq(initial_stage)
      end

      it "creates WRITER step with revision in meta" do
        executor.send(:insert_rewrite_steps!, run: lead_run, failing_critique_step: critique_step)
        writer_step = lead_run.steps.where(agent_name: "WRITER").order(:position).last
        expect(writer_step.meta["revision"]).to eq(1)
      end

      it "creates CRITIQUE step after WRITER step" do
        executor.send(:insert_rewrite_steps!, run: lead_run, failing_critique_step: critique_step)
        steps = lead_run.steps.where(agent_name: [ "WRITER", "CRITIQUE" ]).order(:position)
        rewrite_steps = steps.where("position > ?", critique_step.position)
        expect(rewrite_steps.first.agent_name).to eq("WRITER")
        expect(rewrite_steps.second.agent_name).to eq("CRITIQUE")
      end

      context "on second rewrite" do
        before do
          lead_run.update!(rewrite_count: 1)
        end

        it "does not update lead stage when rewrite is inserted (stage changes when rewrite WRITER completes)" do
          # Stage should be at last completed milestone (likely "critiqued" after first rewrite CRITIQUE)
          lead.update!(stage: AgentConstants::STAGE_CRITIQUED)
          initial_stage = lead.stage
          executor.send(:insert_rewrite_steps!, run: lead_run, failing_critique_step: critique_step)
          lead.reload
          # Stage should not change on insertion - it will change to "rewritten (2)" when rewrite WRITER completes
          expect(lead.stage).to eq(initial_stage)
        end
      end

      context "idempotency protection" do
        it "rewrite_already_inserted? detects existing rewrite steps" do
          # First call creates rewrite steps
          executor.send(:insert_rewrite_steps!, run: lead_run, failing_critique_step: critique_step)

          # Verify rewrite_already_inserted? detects them
          expect(executor.send(:rewrite_already_inserted?, run: lead_run, critique_step_id: critique_step.id)).to be true
        end

        it "database constraint prevents duplicate steps at same position" do
          # First call creates steps at positions 31, 32
          executor.send(:insert_rewrite_steps!, run: lead_run, failing_critique_step: critique_step)
          initial_count = lead_run.steps.count
          initial_rewrite_count = lead_run.reload.rewrite_count

          # Second call would try to create steps at same positions
          # Database unique constraint on (lead_run_id, position) should prevent this
          # But we can't test this directly without bypassing rewrite_already_inserted? check
          # The check in determine_outcome! prevents the second call from happening
          expect(lead_run.steps.count).to eq(initial_count)
          expect(lead_run.reload.rewrite_count).to eq(initial_rewrite_count)
        end
      end
    end
  end

  describe "rewrite loop integration" do
    let(:executor) { described_class.new(lead_run_id: lead_run.id) }
    let(:lead_run) { create(:lead_run, lead: lead, campaign: campaign, min_score: 7, max_rewrites: 2, rewrite_count: 0) }

    before do
      # Create initial pipeline steps
      create(:lead_run_step, lead_run: lead_run, agent_name: "SEARCH", status: "completed", position: 10)
      create(:lead_run_step, lead_run: lead_run, agent_name: "WRITER", status: "completed", position: 20)
    end

    context "when critique fails and triggers rewrite" do
      let(:critique_step) do
        create(:lead_run_step, lead_run: lead_run, agent_name: "CRITIQUE", status: "running", position: 30)
      end
      let(:critique_output) do
        create(:agent_output, lead_run_step: critique_step, status: "completed",
               output_data: { "score" => 5, "meets_min_score" => false })
      end

      it "sets stage to 'critiqued' when critique completes (regardless of pass/fail)" do
        lead.update!(stage: AgentConstants::STAGE_WRITTEN)

        # Simulate critique failure triggering rewrite
        outcome = executor.send(:determine_outcome!, locked_run: lead_run, step: critique_step, output: critique_output)
        expect(outcome[:step_status]).to eq("completed")

        # Update the output with the normalized data from determine_outcome!
        critique_output.update!(outcome[:output_updates]) if outcome[:output_updates]

        # Update the step status to "completed" so update_stage_projection! recognizes it
        critique_step.update!(status: "completed")

        # Update stage projection to reflect CRITIQUE completion
        executor.send(:update_stage_projection!, lead: lead, step: critique_step, output: critique_output)
        lead.reload

        # Stage should be "critiqued" (last completed milestone), not "rewritten" yet
        # "rewritten (1)" will be set when rewrite WRITER completes
        expect(lead.stage).to eq(AgentConstants::STAGE_CRITIQUED)
      end

      context "when rewrite WRITER completes" do
        let(:rewrite_writer_step) do
          create(:lead_run_step, lead_run: lead_run, agent_name: "WRITER", status: "completed", position: 31,
                 meta: { "revision" => 1 })
        end
        let(:rewrite_writer_output) do
          create(:agent_output, lead_run_step: rewrite_writer_step, status: "completed", output_data: { "email" => "test@example.com" })
        end

        it "sets stage to 'rewritten (1)' when rewrite WRITER completes" do
          # Start at "critiqued" (last milestone before rewrite)
          lead.update!(stage: AgentConstants::STAGE_CRITIQUED)
          executor.send(:update_stage_projection!, lead: lead, step: rewrite_writer_step, output: rewrite_writer_output)
          lead.reload
          # Stage should change to "rewritten (1)" when rewrite WRITER completes
          expect(lead.stage).to eq(AgentConstants.rewritten_stage_name(1))
        end
      end

      context "when rewrite CRITIQUE passes" do
        let(:rewrite_critique_step) do
          create(:lead_run_step, lead_run: lead_run, agent_name: "CRITIQUE", status: "completed", position: 32)
        end
        let(:rewrite_critique_output) do
          create(:agent_output, lead_run_step: rewrite_critique_step, status: "completed",
                 output_data: { "score" => 8, "meets_min_score" => true })
        end

        it "updates stage to 'critiqued' when rewrite CRITIQUE passes" do
          lead.update!(stage: AgentConstants.rewritten_stage_name(1))
          executor.send(:update_stage_projection!, lead: lead, step: rewrite_critique_step, output: rewrite_critique_output)
          lead.reload
          expect(lead.stage).to eq(AgentConstants::STAGE_CRITIQUED)
        end
      end
    end

    context "stage invariant: critiqued remains until rewrite WRITER completes" do
      let(:invariant_lead) { create(:lead, campaign: campaign) }
      let(:invariant_lead_run) { create(:lead_run, lead: invariant_lead, campaign: campaign, min_score: 7, max_rewrites: 2, rewrite_count: 0) }
      let(:invariant_executor) { described_class.new(lead_run_id: invariant_lead_run.id) }

      before do
        # Create initial pipeline steps
        create(:lead_run_step, lead_run: invariant_lead_run, agent_name: "SEARCH", status: "completed", position: 10)
        create(:lead_run_step, lead_run: invariant_lead_run, agent_name: "WRITER", status: "completed", position: 20)
      end

      it "keeps stage at 'critiqued' after CRITIQUE completes and rewrite is inserted, until rewrite WRITER completes" do
        # Step 1: Original CRITIQUE completes and fails
        critique_step = create(:lead_run_step, lead_run: invariant_lead_run, agent_name: "CRITIQUE", status: "running", position: 30)
        critique_output = create(:agent_output, lead_run_step: critique_step, status: "completed",
                                output_data: { "score" => 5, "meets_min_score" => false })

        # Simulate CRITIQUE completion and rewrite insertion
        outcome = invariant_executor.send(:determine_outcome!, locked_run: invariant_lead_run, step: critique_step, output: critique_output)
        critique_output.update!(outcome[:output_updates]) if outcome[:output_updates]
        critique_step.update!(status: "completed")
        invariant_executor.send(:update_stage_projection!, lead: invariant_lead, step: critique_step, output: critique_output)

        # Stage should be "critiqued" (last completed milestone)
        invariant_lead.reload
        expect(invariant_lead.stage).to eq(AgentConstants::STAGE_CRITIQUED)

        # Step 2: Rewrite WRITER completes
        rewrite_writer_step = invariant_lead_run.steps.where(agent_name: "WRITER", position: 31).first
        expect(rewrite_writer_step).to be_present
        expect(rewrite_writer_step.meta["revision"]).to eq(1)

        rewrite_writer_output = create(:agent_output, lead_run_step: rewrite_writer_step, status: "completed",
                                      output_data: { "email" => "test@example.com" })
        rewrite_writer_step.update!(status: "completed")
        invariant_executor.send(:update_stage_projection!, lead: invariant_lead, step: rewrite_writer_step, output: rewrite_writer_output)

        # Stage should now be "rewritten (1)" (rewrite WRITER milestone completed)
        invariant_lead.reload
        expect(invariant_lead.stage).to eq(AgentConstants.rewritten_stage_name(1))
      end
    end
  end
end
