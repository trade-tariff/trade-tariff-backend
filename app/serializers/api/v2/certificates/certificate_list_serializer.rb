module Api
  module V2
    module Certificates
      class CertificateListSerializer
        include JSONAPI::Serializer

        set_type :certificate

        set_id :id

        attributes :certificate_type_code,
                   :certificate_code,
                   :description,
                   :formatted_description,
                   :guidance_cds

        attribute :certificate_type_description do |certificate|
          certificate.certificate_type_description&.description
        end

        attribute :validity_start_date do |certificate|
          certificate.certificate_description_period.validity_start_date
        end
      end
    end
  end
end
