module Api
  module V2
    module Csv
      class CommoditySerializer
        include Api::Shared::CsvSerializer

        columns :description,
                :number_indents,
                :goods_nomenclature_item_id

        column :declarable, &:declarable?
        column :leaf, &:leaf?

        columns :goods_nomenclature_sid,
                :formatted_description,
                :description_plain,
                :producline_suffix

        column :parent_sid do |commodity|
          if commodity.parent.is_a?(TenDigitGoodsNomenclature)
            commodity.parent.goods_nomenclature_sid
          end
        end
      end
    end
  end
end
