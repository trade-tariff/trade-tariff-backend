module GoodsNomenclatures
  module NestedSet
    module AncestorAssociations
      extend ActiveSupport::Concern

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
      end
    end
  end
end
