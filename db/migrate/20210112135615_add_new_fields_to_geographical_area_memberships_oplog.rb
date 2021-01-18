Sequel.migration do
  change do
    alter_table :geographical_area_memberships_oplog do
      add_column :geographical_area_hjid, Integer
      add_column :geographical_area_group_hjid, Integer
    end
  end
end
