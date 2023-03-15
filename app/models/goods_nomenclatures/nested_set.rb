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
                   read_only: true do |ds|
        ds.order(:ancestor_nodes__depth)
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
        ds.with_validity_dates(:parent_nodes)
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
    end

    def depth
      values.key?(:depth) ? values[:depth] : tree_node.depth
    end
  end
end
