Sequel.migration do
  up do
    alter_table :search_suggestions do
      add_column :goods_nomenclature_class, String
    end
  end

  down do
    alter_table :search_suggestions do
      drop_column :goods_nomenclature_class
    end
  end
end
