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

      def ancestor_node_constraints(origin, ancestors, date_constraints = origin)
        next_sib = Sequel.qualify(ancestors.table, :next_sibling_or_end_position)
        sibling_ok = next_sib > origin.position

        if historical_query?
          next_sib_start = Sequel.qualify(ancestors.table, :next_sibling_validity_start_date)
          sibling_ok |= (next_sib_start > point_in_time)
        end

        (ancestors.position < origin.position) &
          (ancestors.position >= start_of_chapter(origin.position)) &
          validity_dates_filter(date_constraints.table) &
          sibling_ok
      end

      def historical_query?
        point_in_time.present? && point_in_time.to_date < Date.current
      end

      def descendant_node_constraints(origin, descendants, date_constraints = origin)
        # Current-date queries use the precomputed column on the view; historical
        # queries fall back to the validity-aware subquery because the view stores
        # one next-sibling row per indent and can't answer "at point_in_time".
        origin_next_sib = if historical_query?
                            next_sibling_or_end(origin.position, origin.depth)
                          else
                            Sequel.qualify(origin.table, :next_sibling_or_end_position)
                          end

        (descendants.position > origin.position) &
          validity_dates_filter(date_constraints.table) &
          (descendants.position < origin_next_sib)
      end
    end

    dataset_module do
      def join_child_sids
        join_child_nodes
          .select_all(:goods_nomenclature_tree_nodes)
          .select_append \
            Sequel.qualify(:child_nodes, :goods_nomenclature_sid)
                  .as(:child_sid)
      end

    private

      def join_child_nodes
        origin   = GoodsNomenclatures::TreeNodeAlias.new(model.table_name)
        children = GoodsNomenclatures::TreeNodeAlias.new(:child_nodes)

        actual.left_join \
          model.table_name,
          (children.depth =~ (origin.depth + 1)) &
            model.descendant_node_constraints(origin, children, children),
          table_alias: :child_nodes
      end
    end
  end
end
