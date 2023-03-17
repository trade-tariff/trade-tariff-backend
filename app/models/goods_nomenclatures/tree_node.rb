module GoodsNomenclatures
  class TreeNode < Sequel::Model(:goods_nomenclature_tree_nodes)
    END_OF_TREE           = 1_000_000_000_000
    ROUND_DOWN_TO_CHAPTER = 10_000_000_000

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
      def refresh!(concurrently: false)
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
        (position_column / ROUND_DOWN_TO_CHAPTER) * ROUND_DOWN_TO_CHAPTER
      end

      def next_sibling(origin_position, origin_depth)
        siblings_position = Sequel.qualify(:siblings, :position)
        siblings_depth    = Sequel.qualify(:siblings, :depth)
        siblings_table    = Sequel.as(table_name, :siblings)

        from(siblings_table)
          .select { Sequel.as(min(siblings_position), :next_sibling) }
          .where do |_query|
            (siblings_depth =~ origin_depth) &
              (siblings_position > origin_position) &
              validity_dates_filter(:siblings)
          end
      end

      def ancestor_node_constraints(origin, ancestors)
        (ancestors.position < origin.position) &
          (ancestors.position >= start_of_chapter(origin.position)) &
          validity_dates_filter(origin.table) &
          (ancestors.position =~ previous_sibling(origin.position, ancestors.depth))
      end

      def descendant_node_constraints(origin, descendants)
        (descendants.position > origin.position) &
          validity_dates_filter(origin.table) &
          (descendants.position <
            Sequel.function(:coalesce,
                            next_sibling(origin.position, origin.depth),
                            END_OF_TREE))
      end
    end
  end
end
