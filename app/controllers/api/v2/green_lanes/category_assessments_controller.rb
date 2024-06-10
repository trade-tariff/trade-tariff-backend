module Api
  module V2
    module GreenLanes
      class CategoryAssessmentsController < BaseController
        def index
          category_assessments =
            ::GreenLanes::CategoryAssessment
              .eager(
                theme: [],
                base_regulation: [],
                modification_regulation: [],
                measure_type: %i[measure_type_description measure_type_series_description],
                measures: {
                  additional_code: :additional_code_descriptions,
                  measure_conditions: { certificate: %i[certificate_descriptions exempting_certificate_override] },
                  geographical_area: :geographical_area_descriptions,
                  measure_excluded_geographical_areas: [],
                  excluded_geographical_areas: :geographical_area_descriptions,
                  measure_type: [],
                },
                green_lanes_measures: [],
                exemptions: [],
              )
              .all

          presented_assessments =
            CategoryAssessmentPresenter.wrap(category_assessments)

          serializer =
            CategoryAssessmentSerializer
              .new(presented_assessments,
                   include: %w[geographical_area
                               excluded_geographical_areas
                               exemptions
                               theme
                               regulation
                               measure_type])

          render json: serializer.serializable_hash
        end
      end
    end
  end
end
