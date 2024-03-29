module Api
  module V2
    module GreenLanes
      class CategoryAssessmentSerializer
        include JSONAPI::Serializer

        set_type :category_assessment

        set_id :id

        attributes :category,
                   :theme

        has_many :exemptions, serializer: proc { |record, _params|
          case record
          when Certificate
            Api::V2::GreenLanes::CertificateSerializer
          when AdditionalCode
            Api::V2::AdditionalCodeSerializer
          else
            raise 'Unknown type'
          end
        }

        has_one :geographical_area, record_type: :geographical_area, serializer: Api::V2::GeographicalAreaSerializer
        has_many :excluded_geographical_areas, record_type: :geographical_area, serializer: Api::V2::GeographicalAreaSerializer
        has_many :measures, record_type: :measure,
                            serializer: Api::V2::GreenLanes::MeasureSerializer,
                            if: ->(record) { record.is_a? Api::V2::GreenLanes::CategoryAssessmentPresenter }
      end
    end
  end
end
