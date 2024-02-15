# frozen_string_literal: true

module Api
  module V2
    module GreenLanes
      class GoodsNomenclaturePresenter < SimpleDelegator
        attr_reader :applicable_category_assessments

        def initialize(goods_nomenclature, presented_category_assessments)
          super(goods_nomenclature)
          @applicable_category_assessments = presented_category_assessments
        end

        def applicable_category_assessment_ids
          @applicable_category_assessment_ids ||= @applicable_category_assessments.map(&:id)
        end
      end
    end
  end
end
