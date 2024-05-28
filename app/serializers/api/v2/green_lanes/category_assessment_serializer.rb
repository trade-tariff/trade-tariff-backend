module Api
  module V2
    module GreenLanes
      class CategoryAssessmentSerializer
        include JSONAPI::Serializer

        set_type :category_assessment
        set_id :id

        attribute :category_assessment_id if Rails.env.development?

        has_many :exemptions, serializer: lambda { |record, _params|
          case record
          when Certificate
            GreenLanes::CertificateSerializer
          when AdditionalCode
            AdditionalCodeSerializer
          when ExemptionPresenter
            GreenLanes::ExemptionSerializer
          else
            raise 'Unknown type'
          end
        }

        has_one :theme, serializer: ThemeSerializer
        has_one :geographical_area, serializer: GeographicalAreaSerializer
        has_many :excluded_geographical_areas, serializer: GeographicalAreaSerializer
        has_one :measure_type, serializer: Measures::MeasureTypeSerializer
        has_one :regulation, serializer: Measures::MeasureLegalActSerializer
        has_many :measures, serializer: GreenLanes::MeasureSerializer,
                            if: ->(_record, params) { params[:with_measures] }
      end
    end
  end
end
