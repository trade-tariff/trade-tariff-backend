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
                   :producline_suffix,
                   :parent_sid,
                   :supplementary_measure_unit

        has_many :applicable_category_assessments, serializer: CategoryAssessmentSerializer
        has_many :descendant_category_assessments, serializer: CategoryAssessmentSerializer
        has_many :ancestors, serializer: GreenLanes::ReferencedGoodsNomenclatureSerializer
        has_many :descendants, serializer: GreenLanes::ReferencedGoodsNomenclatureSerializer
      end
    end
  end
end
