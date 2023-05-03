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

    def_column_accessor :leaf

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

      def next_sibling_or_end(...)
        Sequel.function(:coalesce, next_sibling(...), END_OF_TREE)
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
          (descendants.position < next_sibling_or_end(origin.position, origin.depth))
      end
    end

    dataset_module do
      def with_leaf_column
        origin   = GoodsNomenclatures::TreeNodeAlias.new(model.table_name)
        children = GoodsNomenclatures::TreeNodeAlias.new(:child_nodes)

        actual
          .select_all(model.table_name)
          .select_append(
            (
              Sequel.function(:count, :child_nodes__goods_nomenclature_indent_sid) =~ 0
            ).as(:leaf),
          )
          .group(columns.map { |col| Sequel.qualify(model.table_name, col) })
          .left_join(
            model.table_name,
            (
              (children.depth =~ (origin.depth + 1)) &
              (children.position > origin.position) &
              model.validity_dates_filter(children.table) &
              (children.position <
                model.next_sibling_or_end(origin.position, origin.depth))
            ),
            table_alias: :child_nodes,
          )
      end
    end
  end
end
