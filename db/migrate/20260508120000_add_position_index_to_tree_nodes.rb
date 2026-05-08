Sequel.migration do
  no_transaction

  up do
    run 'CREATE INDEX CONCURRENTLY goods_nomenclature_tree_nodes_position_index ON uk.goods_nomenclature_tree_nodes (position)'
  end

  down do
    run 'DROP INDEX CONCURRENTLY IF EXISTS uk.goods_nomenclature_tree_nodes_position_index'
  end
end
