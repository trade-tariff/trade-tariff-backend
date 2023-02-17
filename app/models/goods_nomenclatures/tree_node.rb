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

      def previous_sibling(origin_position, origin_depth)
        siblings_position = Sequel.qualify(:siblings, :position)
        siblings_depth    = Sequel.qualify(:siblings, :depth)
        siblings_table    = Sequel.as(table_name, :siblings)

        from(siblings_table)
          .select { Sequel.as(max(siblings_position), :previous_sibling) }
          .where do |_query|
            (siblings_depth =~ origin_depth) &
              (siblings_position < origin_position) &
              (siblings_position >= TreeNode.start_of_chapter(origin_position)) &
              validity_dates_filter(:siblings)
          end
      end

      def start_of_chapter(position_column)
        (position_column / 10_000_000_000) * 10_000_000_000
      end
    end
  end
end
