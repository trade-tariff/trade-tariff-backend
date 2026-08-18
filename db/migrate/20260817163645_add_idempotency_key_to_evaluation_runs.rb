Sequel.migration do
  change do
    alter_table(:evaluation_runs) do
      add_column :idempotency_key, String
      add_index :idempotency_key, unique: true
    end
  end
end
