module Api
  module V2
    module GreenLanes
      class CategoryAssessmentSerializer
        include JSONAPI::Serializer

        set_type :green_lanes_category_assessment

        set_id :id

        attributes :category,
                   :regulation_id,
                   :measure_type_id,
                   :geographical_area,
                   :document_codes,
                   :additional_codes
      end
    end
  end
end