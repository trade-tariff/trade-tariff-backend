Sequel.migration do
  up do
    drop_table(:tariff_update_cds_errors)
  end

  down do
    create_table(:tariff_update_cds_errors) do
      primary_key :id
      String :tariff_update_filename, null: false
      String :model_name
      String :details, text: true
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end
end
