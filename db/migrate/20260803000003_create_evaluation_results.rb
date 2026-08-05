Sequel.migration do
  change do
    create_table(:evaluation_results) do
      primary_key :id
      foreign_key :run_id, :evaluation_runs, null: false, on_delete: :cascade, index: true
      column :source_type, String, null: false
      column :source_id, String, null: false
      column :persona, String, null: false
      column :expected_code, String, null: false
      column :final_code, String
      column :final_rank, Integer
      column :gold_in_top1, TrueClass, null: false, default: false
      column :gold_in_top5, TrueClass, null: false, default: false
      column :latency_seconds, :numeric, size: [10, 2]
      column :cost_usd, :numeric, size: [10, 5]
      column :error, String
      column :trace, :jsonb, null: false, default: '{}'
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      index :persona
      index :expected_code
      index %i[run_id source_id persona], unique: true, name: :evaluation_results_run_source_persona_uidx
    end
  end
end
