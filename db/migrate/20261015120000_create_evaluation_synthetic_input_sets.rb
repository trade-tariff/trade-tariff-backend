Sequel.migration do
  change do
    # rubocop:disable Rails/CreateTableWithTimestamps -- rows here are never updated after
    # creation (a set and its items are frozen the moment they're built), so updated_at would
    # always equal created_at and add nothing. evaluation_gold_query_sets has the same shape.
    create_table(:evaluation_synthetic_input_sets) do
      primary_key :id
      column :name, String, null: false
      column :requested_size, Integer, null: false
      column :actual_size, Integer, null: false
      column :created_by, String
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      index :name, unique: true
    end

    create_table(:evaluation_synthetic_input_set_items) do
      primary_key :id
      foreign_key :set_id, :evaluation_synthetic_input_sets, null: false, on_delete: :cascade
      foreign_key :synthetic_atar_id, :tariff_knowledge_synthetic_atars, null: false, on_delete: :restrict
      column :query, String, null: false
      column :expected_code, String, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      index %i[set_id synthetic_atar_id], unique: true
    end

    alter_table(:evaluation_experiments) do
      add_foreign_key :synthetic_input_set_id, :evaluation_synthetic_input_sets, null: true, on_delete: :restrict, index: true
    end
    # rubocop:enable Rails/CreateTableWithTimestamps
  end
end
