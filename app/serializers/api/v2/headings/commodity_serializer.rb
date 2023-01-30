module Api
  module V2
    module Headings
      class CommoditySerializer
        include JSONAPI::Serializer

        set_type :commodity

        set_id :goods_nomenclature_sid

        attributes :description,
                   :number_indents,
                   :goods_nomenclature_item_id,
                   :leaf,
                   :producline_suffix,
                   :goods_nomenclature_sid,
                   :formatted_description,
                   :description_plain,
                   :parent_sid,
                   :validity_start_date,
                   :validity_end_date,
                   :declarable

        has_many :overview_measures, serializer: Api::V2::Measures::OverviewMeasureSerializer
      end
    end
  end
end
