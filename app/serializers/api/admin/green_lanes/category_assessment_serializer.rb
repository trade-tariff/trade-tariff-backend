module Api
  module Admin
    module GreenLanes
      class CategoryAssessmentSerializer
        include JSONAPI::Serializer

        set_type :category_assessment

        set_id :id

        attributes :measure_type_id,
                   :regulation_id,
                   :regulation_role,
                   :theme_id,
                   :created_at,
                   :updated_at

        has_many :green_lanes_measures, serializer: Api::Admin::GreenLanes::MeasureSerializer
      end
    end
  end
end
