module Api
  module V2
    module GreenLanes
      class CategoryAssessmentsController < BaseController
        TTL = 24.hours

        def index
          render json: cached_json
        end

      private

        def category_assessments
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
              },
              green_lanes_measures: :goods_nomenclature,
              exemptions: [],
            )
            .all
        end

        def presented_assessments
          CategoryAssessmentPresenter.wrap(category_assessments)
        end

        def serializer
          CategoryAssessmentSerializer
            .new(presented_assessments,
                 include: %w[geographical_area
                             excluded_geographical_areas
                             exemptions
                             theme
                             regulation
                             measure_type])
        end

        def cached_json
          Rails.cache.fetch(cache_key, expires_in: TTL) do
            serializer.serializable_hash.to_json
          end
        end

        def cache_key
          [
            'category-assessments-for',
            actual_date.to_fs(:db),
            'latest-assessment-on',
            latest_assessment_update&.iso8601,
          ].join('-')
        end

        def latest_assessment_update
          ::GreenLanes::CategoryAssessment.latest&.updated_at
        end
      end
    end
  end
end
