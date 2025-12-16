class AddMinScoreBoundsToLeadRuns < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :lead_runs, name: "check_lead_runs_min_score_bounds", if_exists: true

    add_check_constraint :lead_runs,
                         "min_score >= 0 AND min_score <= 10",
                         name: "check_lead_runs_min_score_bounds"
  end
end
