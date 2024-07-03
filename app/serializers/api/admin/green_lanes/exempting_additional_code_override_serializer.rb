module Api
  module Admin
    module GreenLanes
      class ExemptingAdditionalCodeOverrideSerializer
        include JSONAPI::Serializer

        set_type :exempting_additional_code_override

        set_id :id

        attributes :additional_code_type_id,
                   :additional_code,
                   :created_at,
                   :updated_at
      end
    end
  end
end
