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

        attribute :measure_pagination do |_object, params|
          if params[:with_measures]
            {
              id: 1,
              type: 'measure_pagination',
              attributes: params[:measure_pagination],
            }
          end
        end

        has_one :theme, serializer: ThemeSerializer
        has_many :green_lanes_measures, serializer: MeasureSerializer, if: ->(_record, params) { params[:with_measures] }, id_method_name: :green_lanes_measure_pks
        has_many :exemptions, serializer: ExemptionSerializer, if: ->(_record, params) { params[:with_exemptions] }, id_method_name: :exemption_pks
      end
    end
  end
end
