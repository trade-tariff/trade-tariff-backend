Sequel.migration do
  up do
    alter_table(:customs_tariff_updates) { drop_column :status }
  end

  down do
    alter_table(:customs_tariff_updates) { add_column :status, String, null: false, default: 'pending' }
  end
end
