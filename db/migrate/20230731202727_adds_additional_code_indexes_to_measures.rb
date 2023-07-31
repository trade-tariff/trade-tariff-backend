Sequel.migration do
  up do
    alter_table :measures_oplog do
      add_index :additional_code_type_id
      add_index :additional_code_id
    end
  end

  down do
    alter_table :measures_oplog do
      drop_index :additional_code_type_id
      drop_index :additional_code_id
    end
  end
end
