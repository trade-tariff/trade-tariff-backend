module Api
  module V2
    module Subheadings
      class CommoditySerializer
        include JSONAPI::Serializer

        set_type :commodity

        set_id :goods_nomenclature_sid

        attributes :formatted_description,
                   :description_plain,
                   :number_indents,
                   :goods_nomenclature_item_id,
                   :producline_suffix,
                   :goods_nomenclature_sid,
                   :parent_sid,
                   :leaf

        attribute :productline_suffix, &:producline_suffix

        has_many :overview_measures, record_type: :measure, serializer: Api::V2::Measures::OverviewMeasureSerializer
      end
    end
  end
end
