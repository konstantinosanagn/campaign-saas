class AllowSkippedStatusOnLeadRunSteps < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :lead_run_steps, name: "check_lead_run_steps_status"

    add_check_constraint :lead_run_steps,
                         "status IN ('queued','running','completed','failed','skipped')",
                         name: "check_lead_run_steps_status"
  end
end


