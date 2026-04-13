Sequel.migration do
  up do
    drop_table :tariff_update_cds_errors
  end

  down do
    create_table :tariff_update_cds_errors do
      primary_key :id
      String :tariff_update_filename, null: false
      String :model_name, null: false
      jsonb :details

      index :tariff_update_filename
    end
  end
end
