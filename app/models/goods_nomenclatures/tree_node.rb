module GoodsNomenclatures
  class TreeNode < Sequel::Model(:goods_nomenclature_tree_nodes)
    class << self
      # Defaults to concurrent refresh to avoid blocking other queries
      # If the Materialized View has never been populated, eg after a
      # rake db:test:prepare or rake db:structure:load then a non-concurrent
      # refresh is required
      def refresh!(concurrently: false)
        db.refresh_view(:goods_nomenclature_tree_nodes, concurrently:)
      end
    end
  end
end
