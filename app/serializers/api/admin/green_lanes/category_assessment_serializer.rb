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
        has_many :green_lanes_measures, serializer: MeasureSerializer, if: ->(_record, params) { params[:with_measures] }
        has_many :exemptions, serializer: ExemptionSerializer, if: ->(_record, params) { params[:with_exemptions] }
      end
    end
  end
end
