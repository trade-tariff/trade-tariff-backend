# See docs/goods-nomenclature-nested-set.md for an explanation of this

module GoodsNomenclatures
  module NestedSet
    extend ActiveSupport::Concern

    included do
      one_to_one :tree_node, key: :goods_nomenclature_sid,
                             class_name: 'GoodsNomenclatures::TreeNode',
                             reciprocal: :goods_nomenclature,
                             read_only: true do |ds|
        ds.with_actual(GoodsNomenclatures::TreeNode)
      end

      many_to_many :ns_ancestors,
                   left_primary_key: :goods_nomenclature_sid,
                   left_key: Sequel.qualify(:origin_nodes, :goods_nomenclature_sid),
                   right_primary_key: :goods_nomenclature_sid,
                   right_key: :goods_nomenclature_sid,
                   class_name: '::GoodsNomenclature',
                   join_table: Sequel.as(:goods_nomenclature_tree_nodes, :ancestor_nodes),
                   after_load: :recursive_ancestor_populator,
                   read_only: true do |ds|
        ds.order(:ancestor_nodes__position)
          .with_validity_dates(:ancestor_nodes)
          .select_append(:ancestor_nodes__depth)
          .join(Sequel.as(:goods_nomenclature_tree_nodes, :origin_nodes)) do |origin_table, ancestors_table, _join_clauses|
            ancestors = TreeNodeAlias.new(ancestors_table)
            origin    = TreeNodeAlias.new(origin_table)

            (ancestors.depth < origin.depth) &
              TreeNode.ancestor_node_constraints(origin, ancestors)
          end
      end

      one_through_one :ns_parent,
                      left_primary_key: :goods_nomenclature_sid,
                      left_key: Sequel.qualify(:origin_nodes, :goods_nomenclature_sid),
                      right_primary_key: :goods_nomenclature_sid,
                      right_key: :goods_nomenclature_sid,
                      class_name: '::GoodsNomenclature',
                      join_table: Sequel.as(:goods_nomenclature_tree_nodes, :parent_nodes),
                      read_only: true do |ds|
        ds.order(:parent_nodes__position)
          .with_validity_dates(:parent_nodes)
          .select_append(:parent_nodes__depth)
          .join(Sequel.as(:goods_nomenclature_tree_nodes, :origin_nodes)) do |origin_table, parents_table, _join_clauses|
            parents = TreeNodeAlias.new(parents_table)
            origin  = TreeNodeAlias.new(origin_table)

            (parents.depth =~ (origin.depth - 1)) &
              TreeNode.ancestor_node_constraints(origin, parents)
          end
      end

      many_to_many :ns_descendants,
                   left_primary_key: :goods_nomenclature_sid,
                   left_key: Sequel.qualify(:origin_nodes, :goods_nomenclature_sid),
                   right_primary_key: :goods_nomenclature_sid,
                   right_key: :goods_nomenclature_sid,
                   class_name: '::GoodsNomenclature',
                   join_table: Sequel.as(:goods_nomenclature_tree_nodes, :descendant_nodes),
                   after_load: :recursive_descendant_populator,
                   read_only: true do |ds|
        ds.order(:descendant_nodes__position)
          .with_validity_dates(:descendant_nodes)
          .select_append(:descendant_nodes__depth)
          .join(Sequel.as(:goods_nomenclature_tree_nodes, :origin_nodes)) do |origin_table, descendants_table, _join_clauses|
            descendants = TreeNodeAlias.new(descendants_table)
            origin      = TreeNodeAlias.new(origin_table)

            (descendants.depth > origin.depth) &
              TreeNode.descendant_node_constraints(origin, descendants)
          end
      end

      many_to_many :ns_children,
                   left_primary_key: :goods_nomenclature_sid,
                   left_key: Sequel.qualify(:origin_nodes, :goods_nomenclature_sid),
                   right_primary_key: :goods_nomenclature_sid,
                   right_key: :goods_nomenclature_sid,
                   class_name: '::GoodsNomenclature',
                   join_table: Sequel.as(:goods_nomenclature_tree_nodes, :child_nodes),
                   read_only: true do |ds|
        ds.order(:child_nodes__position)
          .with_validity_dates(:child_nodes)
          .select_append(:child_nodes__depth)
          .join(Sequel.as(:goods_nomenclature_tree_nodes, :origin_nodes)) do |origin_table, children_table, _join_clauses|
            children = TreeNodeAlias.new(children_table)
            origin   = TreeNodeAlias.new(origin_table)

            (children.depth =~ (origin.depth + 1)) &
              TreeNode.descendant_node_constraints(origin, children)
          end
      end

      one_to_many :ns_measures,
                  primary_key: :goods_nomenclature_sid,
                  key: :goods_nomenclature_sid,
                  class_name: '::Measure',
                  read_only: true do |ds|
        ds.with_actual(Measure)
          .with_regulation_dates_query
          .exclude(measures__measure_type_id: MeasureType.excluded_measure_types)
          .order(Sequel.asc(:measures__geographical_area_id),
                 Sequel.asc(:measures__measure_type_id),
                 Sequel.asc(:measures__additional_code_type_id),
                 Sequel.asc(:measures__additional_code_id),
                 Sequel.asc(:measures__ordernumber),
                 Sequel.desc(:effective_start_date))
      end
    end

    def recursive_ancestor_populator(ancestors)
      @associations ||= { ns_ancestors: ancestors }

      parents_ancestors = ancestors.dup
      parent = parents_ancestors.pop
      @associations[:ns_parent] ||= parent
      return if ancestors.empty?

      parent.recursive_ancestor_populator(parents_ancestors)
    end

    def recursive_descendant_populator(descendants, parent = nil)
      @associations ||= { ns_descendants: descendants }

      if parent
        @associations[:ns_parent] ||= parent

        if parent.associations[:ns_ancestors]
          @associations[:ns_ancestors] ||= (parent.associations[:ns_ancestors] + [parent])
        end
      end

      if descendants.empty?
        @associations[:ns_children] ||= []
        return
      end

      # group descendants by the immediate child they belong to
      childrens_depth = descendants.first.depth
      grouped_by_child = descendants.each.with_object([]) do |descendant, child_groups|
        if childrens_depth == descendant.depth
          child_groups << [descendant, []]
        else
          child_groups.last.last << descendant
        end
      end

      # populate children and assign to own association
      @associations[:ns_children] ||= grouped_by_child.map do |child, childs_descendants|
        child.recursive_descendant_populator(childs_descendants, self)

        child
      end
    end

    def depth
      values.key?(:depth) ? values[:depth] : tree_node.depth
    end

    def ns_declarable?
      producline_suffix == GoodsNomenclatureIndent::NON_GROUPING_PRODUCTLINE_SUFFIX && ns_children.empty?
    end

    def applicable_measures
      ns_ancestors.flat_map(&:ns_measures) + ns_measures
    end
  end
end
