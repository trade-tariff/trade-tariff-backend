# frozen_string_literal: true

module Api
  module V2
    module GreenLanes
      class GoodsNomenclaturePresenter < SimpleDelegator
        attr_reader :applicable_category_assessments

        def initialize(subheading, categories)
          super(subheading)
          @applicable_category_assessments = categories
        end

        def applicable_category_assessment_ids
          @applicable_category_assessment_ids ||= @applicable_category_assessments.map(&:id)
        end
      end
    end
  end
end
