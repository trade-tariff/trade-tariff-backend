Sequel.migration do
  change do
    create_table :tariff_update_state_changes do
      primary_key :id
      String :tariff_update_filename, null: false
      String :from_state, size: 1
      String :to_state, size: 1, null: false
      DateTime :created_at, null: false

      index :tariff_update_filename
    end
  end
end
