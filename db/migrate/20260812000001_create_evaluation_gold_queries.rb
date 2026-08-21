Sequel.migration do
  change do
    # rubocop:disable Rails/CreateTableWithTimestamps
    create_table(:evaluation_gold_queries) do
      primary_key :id
      column :source_type, String, null: false
      column :source_id, String, null: false
      column :persona, String, null: false
      column :query, String, null: false
      column :expected_code, String, null: false
      column :expected_description, String
      column :notes, String
      column :generator, String
      column :active, TrueClass, null: false, default: true
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      index :expected_code
      index %i[source_type source_id persona], unique: true, name: :evaluation_gold_queries_source_persona_uidx
    end
    # rubocop:enable Rails/CreateTableWithTimestamps
  end
end
