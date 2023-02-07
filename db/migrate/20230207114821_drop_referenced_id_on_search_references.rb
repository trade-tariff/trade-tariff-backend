Sequel.migration do
  up do
    alter_table :search_references do
      drop_column :referenced_id
    end
  end

  down do
    alter_table :search_references do
      add_column :referenced_class, String, size: 10
    end
  end
end
