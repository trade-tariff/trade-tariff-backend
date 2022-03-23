module Api
  module V2
    module AdditionalCodes
      class AdditionalCodeSerializer
        include JSONAPI::Serializer

        set_type :additional_code

        set_id :additional_code_sid

        attributes :additional_code_type_id, :additional_code, :code, :description, :formatted_description

        has_many :measures, serializer: Api::V2::Shared::MeasureSerializer
      end
    end
  end
end
