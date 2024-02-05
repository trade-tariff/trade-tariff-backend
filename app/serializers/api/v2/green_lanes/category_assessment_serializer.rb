module Api
  module V2
    module GreenLanes
      class CategoryAssessmentSerializer
        include JSONAPI::Serializer

        set_type :green_lanes_category_assessment

        set_id :id

        attributes :category,
                   :excluded_geographical_areas,
                   :document_codes,
                   :additional_codes,
                   :exemptions,
                   :theme

        has_one :geographical_area, record_type: :geographical_area, serializer: Api::V2::GeographicalAreaSerializer
      end
    end
  end
end
