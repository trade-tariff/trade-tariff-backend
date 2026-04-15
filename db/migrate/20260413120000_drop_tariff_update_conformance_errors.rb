Sequel.migration do
  up do
    drop_table(:tariff_update_conformance_errors, if_exists: true)
  end

  down do
    create_table :tariff_update_conformance_errors do
      primary_key :id
      String :tariff_update_filename, null: false
      String :model_name, null: false
      Text :model_primary_key, null: false
      Text :model_values
      Text :model_conformance_errors

      index :tariff_update_filename
    end
  end
end
