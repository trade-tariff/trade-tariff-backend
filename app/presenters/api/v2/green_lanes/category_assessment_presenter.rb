module Api
  module V2
    module GreenLanes
      class CategoryAssessmentPresenter < SimpleDelegator
        attr_reader :measures

        def initialize(category_assessment, measures)
          super(category_assessment)
          @measures = measures
        end

        def measure_ids
          @measure_ids = measures.map(&:measure_sid)
        end
      end
    end
  end
end
