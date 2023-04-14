Sequel.migration do
  up do
    alter_table :search_suggestions do
      add_column :type, String
      add_column :priority, Integer
      add_column :goods_nomenclature_sid, Integer
    end

    add_index :search_suggestions, :type
    add_index :search_suggestions, :goods_nomenclature_sid
  end

  down do
    alter_table :search_suggestions do
      drop_column :type
      drop_column :priority
      drop_column :goods_nomenclature_sid
    end
  end
end
