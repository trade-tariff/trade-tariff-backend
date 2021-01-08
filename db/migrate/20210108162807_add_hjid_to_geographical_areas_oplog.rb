Sequel.migration do
  change do
    alter_table :geographical_areas_oplog do
      add_column :hjid, Integer
    end
  end
end
