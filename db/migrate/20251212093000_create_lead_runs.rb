class CreateLeadRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :lead_runs do |t|
      t.references :lead, null: false, foreign_key: true
      t.references :campaign, null: false, foreign_key: true

      # queued|running|completed|failed|cancelled
      t.string :status, null: false, limit: 20, default: "queued"

      # Optional redundancy for display/debug; canonical ordering is lead_run_steps.
      t.jsonb :plan, null: false, default: {}

      # Settings snapshot + provenance (stored as JSONB with string keys).
      t.jsonb :config_snapshot, null: false, default: {}

      t.integer :rewrite_count, null: false, default: 0
      t.integer :max_rewrites, null: false, default: 2
      t.integer :min_score, null: false, default: 6

      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    # Authoritative: only one active run per lead.
    add_index :lead_runs,
              :lead_id,
              unique: true,
              where: "status IN ('queued','running')",
              name: "index_lead_runs_one_active_per_lead"

    add_index :lead_runs, [ :lead_id, :status ], name: "index_lead_runs_on_lead_id_and_status"
    add_index :lead_runs, [ :campaign_id, :status ], name: "index_lead_runs_on_campaign_id_and_status"

    add_check_constraint :lead_runs,
                         "status IN ('queued','running','completed','failed','cancelled')",
                         name: "check_lead_runs_status"
  end
end
