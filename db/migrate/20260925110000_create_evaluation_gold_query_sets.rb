Sequel.migration do
  up do
    create_table(:evaluation_gold_query_sets) do
      primary_key :id
      column :name, String, null: false
      column :requested_size, Integer, null: false
      column :atar_percentage, Integer, null: false
      column :planned_count, Integer, null: false
      column :generated_count, Integer, null: false, default: 0
      column :failed_count, Integer, null: false, default: 0
      column :status, String, null: false
      # One entry per item that could not be generated: {source_type, source_id, error}.
      column :failures, :jsonb, null: false, default: '[]'
      column :created_by, String
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      index :name, unique: true

      constraint(:evaluation_gold_query_sets_status_check, Sequel.lit("status IN ('generating', 'ready', 'partly_failed', 'failed')"))
      constraint(:evaluation_gold_query_sets_atar_percentage_check, Sequel.lit('atar_percentage BETWEEN 0 AND 100'))
    end

    # The gold queries that exist today were only made to prove that the eval app can run
    # remotely. They belong to no set, so they are deleted rather than migrated. This must
    # come before the NOT NULL columns below, which could not be added to existing rows.
    run 'DELETE FROM evaluation_gold_queries'

    alter_table(:evaluation_gold_queries) do
      add_foreign_key :set_id, :evaluation_gold_query_sets, null: false, on_delete: :cascade
      add_column :oracle_text, String, null: false
      drop_index %i[source_type source_id persona], name: :evaluation_gold_queries_source_persona_uidx
      add_index %i[set_id source_type source_id persona], unique: true, name: :evaluation_gold_queries_set_source_persona_uidx
    end

    alter_table(:evaluation_experiments) do
      add_foreign_key :gold_query_set_id, :evaluation_gold_query_sets, null: true, on_delete: :restrict, index: true
    end
  end

  # The deleted gold queries cannot be restored.
  down do
    alter_table(:evaluation_experiments) do
      drop_foreign_key :gold_query_set_id
    end

    run 'DELETE FROM evaluation_gold_queries'

    alter_table(:evaluation_gold_queries) do
      drop_index %i[set_id source_type source_id persona], name: :evaluation_gold_queries_set_source_persona_uidx
      drop_column :oracle_text
      drop_foreign_key :set_id
      add_index %i[source_type source_id persona], unique: true, name: :evaluation_gold_queries_source_persona_uidx
    end

    drop_table(:evaluation_gold_query_sets)
  end
end
