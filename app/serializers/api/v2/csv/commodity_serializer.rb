module Api
  module V2
    module Csv
      class CommoditySerializer
        include Api::Shared::CsvSerializer

        columns :description,
                :number_indents,
                :goods_nomenclature_item_id

        column :declarable, &:ns_declarable?
        column :leaf, &:ns_leaf?

        columns :goods_nomenclature_sid,
                :formatted_description,
                :description_plain,
                :producline_suffix

        column :parent_sid do |commodity|
          if commodity.ns_parent.is_a?(Commodity)
            commodity.ns_parent.goods_nomenclature_sid
          end
        end
      end
    end
  end
end
