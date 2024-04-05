# frozen_string_literal: true

module Api
  module V2
    module GreenLanes
      class GoodsNomenclaturePresenter < SimpleDelegator
        def initialize(goods_nomenclature, geographical_area_id = nil)
          super(goods_nomenclature)
          @geographical_area_id = geographical_area_id.presence
        end

        def applicable_category_assessment_ids
          @applicable_category_assessment_ids ||= applicable_category_assessments.map(&:id)
        end

        def applicable_category_assessments
          @applicable_category_assessments ||=
            ::GreenLanes::FindCategoryAssessmentsService.call \
              goods_nomenclature: self,
              geographical_area_id: @geographical_area_id
        end
      end
    end
  end
end
