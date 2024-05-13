module Api
  module Admin
    module GreenLanes
      class ExemptingCertificateOverrideSerializer
        include JSONAPI::Serializer

        set_type :exempting_certificate_override

        set_id :id

        attributes :certificate_type_code,
                   :certificate_code,
                   :created_at,
                   :updated_at
      end
    end
  end
end
