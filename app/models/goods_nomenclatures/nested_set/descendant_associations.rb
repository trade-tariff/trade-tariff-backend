module GoodsNomenclatures
  module NestedSet
    module DescendantAssociations
      extend ActiveSupport::Concern

      included do
        DescendantAssociations.register_descendants(self)
        DescendantAssociations.register_children(self)
        DescendantAssociations.register_historical_children(self)
      end

      def self.register_descendants(model)
        model.many_to_many :descendants,
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
      end

      def self.register_children(model)
        model.many_to_many :children,
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
      end

      def self.register_historical_children(model)
        model.many_to_many :historical_children,
                           left_primary_key: :goods_nomenclature_sid,
                           left_key: Sequel.qualify(:origin_nodes, :goods_nomenclature_sid),
                           right_primary_key: :goods_nomenclature_sid,
                           right_key: :goods_nomenclature_sid,
                           class_name: '::GoodsNomenclature',
                           join_table: Sequel.as(:goods_nomenclature_tree_nodes, :child_nodes),
                           read_only: true do |ds|
          ds.non_hidden
            .order(:child_nodes__position)
            .select_append(:child_nodes__depth, :child_nodes__number_indents)
            .join(Sequel.as(:goods_nomenclature_tree_nodes, :origin_nodes)) do |origin_table, children_table, _|
              children = TreeNodeAlias.new(children_table)
              origin   = TreeNodeAlias.new(origin_table)

              # no with_validity_dates here -> no point-in-time filter
              (children.depth =~ (origin.depth + 1)) &
                TreeNode.descendant_node_constraints(origin, children, children)
            end
        end
      end
    end
  end
end
