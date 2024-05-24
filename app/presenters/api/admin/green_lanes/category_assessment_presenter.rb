module Api
  module Admin
    module GreenLanes
      class CategoryAssessmentPresenter < WrapDelegator
        def green_lanes_measure_ids
          green_lanes_measures.map(&:id)
        end

        def exemption_ids
          exemptions.map(&:id)
        end
      end
    end
  end
end
