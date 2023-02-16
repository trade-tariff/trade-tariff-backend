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
    end
  end
end
