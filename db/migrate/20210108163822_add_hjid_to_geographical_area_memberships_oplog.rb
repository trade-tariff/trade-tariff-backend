Sequel.migration do
  change do
    alter_table :geographical_area_memberships_oplog do
      add_column :hjid, Integer
    end
  end
end
