module Api
  module V2
    module Certificates
      class CertificatesSerializer
        include JSONAPI::Serializer

        set_id :id

        attributes :certificate_type_code,
                   :certificate_code,
                   :description,
                   :formatted_description,
                   :guidance_cds,
                   :guidance_chief

        has_many :measures, serializer: Api::V2::Shared::MeasureSerializer
      end
    end
  end
end
