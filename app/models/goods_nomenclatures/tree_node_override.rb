module GoodsNomenclatures
  class TreeNodeOverride < Sequel::Model(:goods_nomenclature_tree_node_overrides)
    # Explicitly removing :timestamps plugin
    # Data migrations may end up being re-run but the time stamps are used to
    # determine whether to favour a newer oplog entry on the indents table or
    # not so should be explicitly set
    plugin :auto_validations, not_null: :presence
  end
end
