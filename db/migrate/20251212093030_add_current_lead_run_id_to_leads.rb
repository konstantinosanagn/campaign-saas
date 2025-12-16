class AddCurrentLeadRunIdToLeads < ActiveRecord::Migration[8.1]
  def change
    add_reference :leads, :current_lead_run, null: true, foreign_key: { to_table: :lead_runs }
  end
end
