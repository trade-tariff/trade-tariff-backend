# Full explanation in docs/goods-nomenclature-nested-set.md
# For usage - see the 'Querying in Ruby` section in the above document

module GoodsNomenclatures
  module NestedSet
    extend ActiveSupport::Concern

    class DateNotSet < RuntimeError
      def initialize
        super 'TimeMachine date is not set, code should be inside TimeMachine.now {}'
      end
    end

    included do
      one_to_one :tree_node, key: :goods_nomenclature_sid,
                             class_name: 'GoodsNomenclatures::TreeNode',
                             reciprocal: :goods_nomenclature,
                             graph_use_association_block: true,
                             read_only: true do |ds|
        ds.with_actual(GoodsNomenclatures::TreeNode)
      end

      many_to_many :ancestors,
                   left_primary_key: :goods_nomenclature_sid,
                   left_key: Sequel.qualify(:origin_nodes, :goods_nomenclature_sid),
                   right_primary_key: :goods_nomenclature_sid,
                   right_key: :goods_nomenclature_sid,
                   class_name: '::GoodsNomenclature',
                   join_table: Sequel.as(:goods_nomenclature_tree_nodes, :ancestor_nodes),
                   after_load: :recursive_ancestor_populator,
                   read_only: true do |ds|
        raise DateNotSet unless TimeMachine.date_is_set?

        ds.order(:ancestor_nodes__position)
          .with_validity_dates(:ancestor_nodes)
          .select_append(:ancestor_nodes__depth)
          .select_append(:ancestor_nodes__number_indents)
          .select_append(Sequel.as(false, :leaf))
          .join(Sequel.as(:goods_nomenclature_tree_nodes, :origin_nodes)) do |origin_table, ancestors_table, _join_clauses|
            ancestors = TreeNodeAlias.new(ancestors_table)
            origin    = TreeNodeAlias.new(origin_table)

            (ancestors.depth < origin.depth) &
              TreeNode.ancestor_node_constraints(origin, ancestors)
          end
      end

      one_through_one :parent,
                      left_primary_key: :goods_nomenclature_sid,
                      left_key: Sequel.qualify(:origin_nodes, :goods_nomenclature_sid),
                      right_primary_key: :goods_nomenclature_sid,
                      right_key: :goods_nomenclature_sid,
                      class_name: '::GoodsNomenclature',
                      join_table: Sequel.as(:goods_nomenclature_tree_nodes, :parent_nodes),
                      read_only: true do |ds|
        raise DateNotSet unless TimeMachine.date_is_set?

        ds.order(:parent_nodes__position)
          .with_validity_dates(:parent_nodes)
          .select_append(:parent_nodes__depth)
          .select_append(:parent_nodes__number_indents)
          .select_append(Sequel.as(false, :leaf))
          .join(Sequel.as(:goods_nomenclature_tree_nodes, :origin_nodes)) do |origin_table, parents_table, _join_clauses|
            parents = TreeNodeAlias.new(parents_table)
            origin  = TreeNodeAlias.new(origin_table)

            (parents.depth =~ (origin.depth - 1)) &
              TreeNode.ancestor_node_constraints(origin, parents)
          end
      end

      many_to_many :descendants,
                   left_primary_key: :goods_nomenclature_sid,
                   left_key: Sequel.qualify(:origin_nodes, :goods_nomenclature_sid),
                   right_primary_key: :goods_nomenclature_sid,
                   right_key: :goods_nomenclature_sid,
                   class_name: '::GoodsNomenclature',
                   join_table: Sequel.as(:goods_nomenclature_tree_nodes, :descendant_nodes),
                   after_load: :recursive_descendant_populator,
                   read_only: true do |ds|
        raise DateNotSet unless TimeMachine.date_is_set?

        ds.non_hidden
          .order(:descendant_nodes__position)
          .with_validity_dates(:descendant_nodes)
          .select_append(:descendant_nodes__depth)
          .select_append(:descendant_nodes__number_indents)
          .join(Sequel.as(:goods_nomenclature_tree_nodes, :origin_nodes)) do |origin_table, descendants_table, _join_clauses|
            descendants = TreeNodeAlias.new(descendants_table)
            origin      = TreeNodeAlias.new(origin_table)

            (descendants.depth > origin.depth) &
              TreeNode.descendant_node_constraints(origin, descendants)
          end
      end

      many_to_many :children,
                   left_primary_key: :goods_nomenclature_sid,
                   left_key: Sequel.qualify(:origin_nodes, :goods_nomenclature_sid),
                   right_primary_key: :goods_nomenclature_sid,
                   right_key: :goods_nomenclature_sid,
                   class_name: '::GoodsNomenclature',
                   join_table: Sequel.as(:goods_nomenclature_tree_nodes, :child_nodes),
                   read_only: true do |ds|
        raise DateNotSet unless TimeMachine.date_is_set?

        ds.non_hidden
          .order(:child_nodes__position)
          .with_validity_dates(:child_nodes)
          .select_append(:child_nodes__depth)
          .select_append(:child_nodes__number_indents)
          .join(Sequel.as(:goods_nomenclature_tree_nodes, :origin_nodes)) do |origin_table, children_table, _join_clauses|
            children = TreeNodeAlias.new(children_table)
            origin   = TreeNodeAlias.new(origin_table)

            (children.depth =~ (origin.depth + 1)) &
              TreeNode.descendant_node_constraints(origin, children)
          end
      end

      one_to_many :measures,
                  primary_key: :goods_nomenclature_sid,
                  key: :goods_nomenclature_sid,
                  class_name: '::Measure',
                  read_only: true do |ds|
        ds.with_actual(Measure)
          .dedupe_similar
          .with_regulation_dates_query
          .without_excluded_types
      end

      one_to_many :overview_measures,
                  primary_key: :goods_nomenclature_sid,
                  key: :goods_nomenclature_sid,
                  class_name: '::Measure',
                  read_only: true do |ds|
        ds.with_actual(Measure)
          .dedupe_similar
          .with_regulation_dates_query
          .without_excluded_types
          .overview
      end

      def_column_accessor :leaf

      dataset_module do
        def with_leaf_column
          association_inner_join(tree_node: proc { |ds| ds.join_child_sids })
            .select_all(:goods_nomenclatures)
            .select_append(:tree_node__number_indents, :tree_node__depth)
            .select_append(Sequel.as({ tree_node__child_sid: nil }, :leaf))
            .distinct
        end

        def declarable
          with_leaf_column
            .where(tree_node__child_sid: nil,
                   goods_nomenclatures__producline_suffix:
                     GoodsNomenclatureIndent::NON_GROUPING_PRODUCTLINE_SUFFIX)
        end
      end
    end

    def recursive_ancestor_populator(ancestors)
      @associations ||= {}
      @associations[:ancestors] ||= ancestors

      parents_ancestors = ancestors.dup
      parent = parents_ancestors.pop
      @associations[:parent] ||= parent
      return if ancestors.empty?

      parent.recursive_ancestor_populator(parents_ancestors)
    end

    def recursive_descendant_populator(descendants, parent = nil)
      @associations ||= {}
      @associations[:descendants] ||= descendants

      if parent
        @associations[:parent] ||= parent

        if parent.associations[:ancestors]
          @associations[:ancestors] ||= (parent.associations[:ancestors] + [parent])
        end
      end

      if descendants.empty?
        @associations[:children] ||= []
        return
      end

      # group descendants by the immediate child they belong to
      grouped_by_child = descendants.each.with_object({}) do |descendant, all_children|
        if descendant.depth == (depth + 1)
          all_children[descendant] = []
        elsif (last_child = all_children.keys.last)
          all_children[last_child] << descendant
        end
      end

      # populate children and assign to own association
      @associations[:children] ||= grouped_by_child.map do |child, childs_descendants|
        child.recursive_descendant_populator(childs_descendants, self)

        child
      end
    end

    def depth
      values.key?(:depth) ? values[:depth] : tree_node.depth
    end

    def declarable?
      producline_suffix == GoodsNomenclatureIndent::NON_GROUPING_PRODUCTLINE_SUFFIX && leaf?
    end

    def leaf?
      values.key?(:leaf) ? values[:leaf] : children.empty?
    end

    def applicable_measures
      (ancestors.flat_map(&:measures) + measures).sort
    end

    def applicable_overview_measures
      (ancestors.flat_map(&:overview_measures) + overview_measures).sort
    end
  end
end
