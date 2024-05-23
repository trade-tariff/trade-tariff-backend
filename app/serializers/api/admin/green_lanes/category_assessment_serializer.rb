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
                   :theme_id

        has_one :theme, serializer: ThemeSerializer
      end
    end
  end
end
