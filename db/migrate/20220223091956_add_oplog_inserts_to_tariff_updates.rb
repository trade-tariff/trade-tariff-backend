Sequel.migration do
  change do
    alter_table :tariff_updates do
      add_column :inserts, String
    end
  end
end
