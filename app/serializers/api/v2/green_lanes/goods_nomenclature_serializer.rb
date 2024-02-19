module Api
  module V2
    module GreenLanes
      class GoodsNomenclatureSerializer
        include JSONAPI::Serializer

        set_type :goods_nomenclature

        set_id :goods_nomenclature_sid

        attributes :goods_nomenclature_sid,
                   :goods_nomenclature_item_id,
                   :description,
                   :formatted_description,
                   :validity_start_date,
                   :validity_end_date,
                   :description_plain,
                   :producline_suffix

        has_many :applicable_category_assessments, record_type: :category_assessment, serializer: Api::V2::GreenLanes::CategoryAssessmentSerializer
      end
    end
  end
end
