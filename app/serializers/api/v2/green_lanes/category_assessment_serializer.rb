module Api
  module V2
    module GreenLanes
      class CategoryAssessmentSerializer
        include JSONAPI::Serializer

        set_type :category_assessment

        set_id :id

        attributes :category,
                   :theme

        has_many :exemptions, serializer: lambda { |record, _params|
          case record
          when Certificate
            GreenLanes::CertificateSerializer
          when AdditionalCode
            AdditionalCodeSerializer
          else
            raise 'Unknown type'
          end
        }

        has_one :geographical_area, serializer: GeographicalAreaSerializer
        has_many :excluded_geographical_areas, serializer: GeographicalAreaSerializer
        has_many :measures, serializer: GreenLanes::MeasureSerializer,
                            if: ->(record) { record.is_a? CategoryAssessmentPresenter }
      end
    end
  end
end
