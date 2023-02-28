module GoodsNomenclatures
  module NestedSet
    extend ActiveSupport::Concern

    END_OF_TREE = 1_000_000_000_000

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
        ds.order(:ancestor_nodes__depth)
          .with_validity_dates(:ancestor_nodes)
          .select_append(:ancestor_nodes__depth)
          .join(Sequel.as(:goods_nomenclature_tree_nodes, :origin_nodes)) do |origin_table, ancestors_table, _join_clauses|
            ancestors_position = Sequel.qualify(ancestors_table, :position)
            ancestors_depth    = Sequel.qualify(ancestors_table, :depth)
            origin_position    = Sequel.qualify(origin_table, :position)
            origin_depth       = Sequel.qualify(origin_table, :depth)

            (ancestors_depth < origin_depth) &
              (ancestors_position < origin_position) &
              (ancestors_position >= TreeNode.start_of_chapter(origin_position)) &
              model.validity_dates_filter(origin_table) &
              (ancestors_position =~ TreeNode.previous_sibling(origin_position, ancestors_depth))
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
          .join(Sequel.as(:goods_nomenclature_tree_nodes, :origin_nodes)) do |origin_table, ancestors_table, _join_clauses|
            ancestors_position = Sequel.qualify(ancestors_table, :position)
            ancestors_depth    = Sequel.qualify(ancestors_table, :depth)
            origin_position    = Sequel.qualify(origin_table, :position)
            origin_depth       = Sequel.qualify(origin_table, :depth)

            (ancestors_depth =~ (origin_depth - 1)) &
              (ancestors_position < origin_position) &
              (ancestors_position >= TreeNode.start_of_chapter(origin_position)) &
              model.validity_dates_filter(origin_table) &
              (ancestors_position =~ TreeNode.previous_sibling(origin_position, ancestors_depth))
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
            descendants_position = Sequel.qualify(descendants_table, :position)
            descendants_depth    = Sequel.qualify(descendants_table, :depth)
            origin_position      = Sequel.qualify(origin_table, :position)
            origin_depth         = Sequel.qualify(origin_table, :depth)

            (descendants_depth > origin_depth) &
              (descendants_position > origin_position) &
              model.validity_dates_filter(origin_table) &
              (descendants_position <
                Sequel.function(
                  :coalesce,
                  TreeNode.next_sibling(origin_position, origin_depth),
                  END_OF_TREE,
                )
              )
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
          .join(Sequel.as(:goods_nomenclature_tree_nodes, :origin_nodes)) do |origin_table, descendants_table, _join_clauses|
            descendants_position = Sequel.qualify(descendants_table, :position)
            descendants_depth    = Sequel.qualify(descendants_table, :depth)
            origin_position      = Sequel.qualify(origin_table, :position)
            origin_depth         = Sequel.qualify(origin_table, :depth)

            (descendants_depth =~ (origin_depth + 1)) &
              (descendants_position > origin_position) &
              model.validity_dates_filter(origin_table) &
              (descendants_position <
                Sequel.function(
                  :coalesce,
                  TreeNode.next_sibling(origin_position, origin_depth),
                  END_OF_TREE,
                )
              )
          end
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
  end
end
