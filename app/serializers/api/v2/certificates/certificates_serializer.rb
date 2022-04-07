module Api
  module V2
    module Certificates
      class CertificatesSerializer
        include JSONAPI::Serializer

        set_id :id

        attributes :certificate_type_code,
                   :certificate_code,
                   :description,
                   :formatted_description

        attribute :guidance_cds do |certificate|
          TradeTariffBackend
            .chief_cds_guidance
            .cds_guidance_for("#{certificate.certificate_type_code}#{certificate.certificate_code}")
        end

        attribute :guidance_chief do |certificate|
          TradeTariffBackend
            .chief_cds_guidance
            .chief_guidance_for("#{certificate.certificate_type_code}#{certificate.certificate_code}")
        end

        has_many :measures, serializer: Api::V2::Shared::MeasureSerializer
      end
    end
  end
end
