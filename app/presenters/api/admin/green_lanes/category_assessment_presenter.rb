module Api
  module Admin
    module GreenLanes
      class CategoryAssessmentPresenter < SimpleDelegator
        attr_reader :green_lanes_measures

        def initialize(category_assessment, measures)
          @green_lanes_measures = measures

          super(category_assessment)
        end

        def green_lanes_measure_ids
          @green_lanes_measure_ids ||= @green_lanes_measures.map(&:id)
        end
      end
    end
  end
end
