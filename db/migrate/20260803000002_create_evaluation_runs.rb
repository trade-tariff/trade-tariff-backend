Sequel.migration do
  change do
    create_table(:evaluation_runs) do
      primary_key :id
      foreign_key :experiment_id, :evaluation_experiments, null: false, on_delete: :restrict, index: true
      column :status, String, null: false
      column :triggered_by, String, null: false
      column :configuration_digest, String, size: 16
      column :effective_configuration, :jsonb, null: false, default: '{}'
      column :question_model, String
      column :simulator_model, String
      column :started_at, :timestamptz
      column :completed_at, :timestamptz
      column :total_cost_usd, :numeric, size: [10, 5]
      column :total_provider_calls, Integer, null: false, default: 0
      column :total_latency_seconds, :numeric, size: [10, 2]
      column :result_count, Integer, null: false, default: 0
      column :error_count, Integer, null: false, default: 0
      column :error_summary, String
      column :aggregate_metrics, :jsonb, null: false, default: '{}'
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      index :status
      index :configuration_digest
      index :question_model
      index :simulator_model

      constraint(
        :evaluation_runs_status_check,
        Sequel.lit("status IN ('queued', 'running', 'completed', 'partially_failed', 'failed', 'cancelled')"),
      )
    end
  end
end
