module Api
  module V2
    module GreenLanes
      class CategoryAssessmentSerializer
        include JSONAPI::Serializer

        set_type :green_lanes_category_assessment

        set_id :id

        attributes :category,
                   :geographical_area,
                   :excluded_geographical_areas,
                   :document_codes,
                   :additional_codes,
                   :exemptions,
                   :theme
      end
    end
  end
end
