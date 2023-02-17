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
    end

    def depth
      values.key?(:depth) ? values[:depth] : tree_node.depth
    end
  end
end
