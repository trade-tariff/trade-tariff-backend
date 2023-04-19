Sequel.migration do
  up do
    create_table :goods_nomenclature_tree_node_overrides do
      primary_key :id
      Integer :goods_nomenclature_indent_sid, null: false
      Integer :depth, null: false
      DateTime :created_at, null: false
      DateTime :updated_at
    end

    add_index :goods_nomenclature_tree_node_overrides, :goods_nomenclature_indent_sid, unique: true
    add_index :goods_nomenclature_tree_node_overrides, :created_at
    add_index :goods_nomenclature_tree_node_overrides, :updated_at
  end

  down do
    drop_table :goods_nomenclature_tree_node_overrides
  end
end
