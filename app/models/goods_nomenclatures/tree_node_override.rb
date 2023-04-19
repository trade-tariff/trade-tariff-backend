module GoodsNomenclatures
  class TreeNodeOverride < Sequel::Model(:goods_nomenclature_tree_node_overrides)
    plugin :timestamps
    plugin :auto_validations, not_null: :presence
  end
end
