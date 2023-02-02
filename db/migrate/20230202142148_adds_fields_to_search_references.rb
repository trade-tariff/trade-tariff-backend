Sequel.migration do
  up do
    alter_table :search_references do
      add_column :goods_nomenclature_sid, Integer
      add_column :goods_nomenclature_item_id, String
    end
  end

  down do
    alter_table :search_references do
      drop_column :goods_nomenclature_sid
      drop_column :goods_nomenclature_item_id
    end
  end
end
