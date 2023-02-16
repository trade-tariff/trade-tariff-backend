module GoodsNomenclatures
  class TreeNode < Sequel::Model(:goods_nomenclature_tree_nodes)
    plugin :time_machine
    set_primary_key :goods_nomenclature_indent_sid

    one_to_one :goods_nomenclature, primary_key: :goods_nomenclature_sid,
                                    key: :goods_nomenclature_sid,
                                    class_name: '::GoodsNomenclature',
                                    reciprocal: :tree_node,
                                    read_only: true

    class << self
      # Defaults to concurrent refresh to avoid blocking other queries
      # If the Materialized View has never been populated, eg after a
      # rake db:test:prepare or rake db:structure:load then a non-concurrent
      # refresh is required
      def refresh!(concurrently: true)
        db.refresh_view(:goods_nomenclature_tree_nodes, concurrently:)
      end
    end
  end
end
