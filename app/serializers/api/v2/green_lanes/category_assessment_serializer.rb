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
      end
    end
  end
end
