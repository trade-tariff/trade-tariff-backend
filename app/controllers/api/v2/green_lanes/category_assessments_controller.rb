module Api
  module V2
    module GreenLanes
      class CategoryAssessmentsController < BaseController
        def index
          category_assessments =
            ::GreenLanes::CategoryAssessment
              .eager(
                theme: [],
                measures: {
                  additional_code: [],
                  measure_conditions: :certificate,
                  geographical_area: :geographical_area_descriptions,
                  measure_excluded_geographical_areas: {
                    geographical_area: :geographical_area_descriptions,
                  },
                },
              )
              .all

          presented_assessments =
            CategoryAssessmentPresenter.wrap(category_assessments)

          serializer =
            Api::V2::GreenLanes::CategoryAssessmentSerializer
              .new(presented_assessments,
                   include: %w[geographical_area excluded_geographical_areas])

          render json: serializer.serializable_hash
        end
      end
    end
  end
end
