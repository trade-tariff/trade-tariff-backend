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
          guidance = TradeTariffBackend.chief_cds_guidance.guidance_for("#{certificate.certificate_type_code}#{certificate.certificate_code}")

          guidance.try(:[], 'guidance_cds')
        end

        attribute :guidance_chief do |certificate|
          guidance = TradeTariffBackend.chief_cds_guidance.guidance_for("#{certificate.certificate_type_code}#{certificate.certificate_code}")

          guidance.try(:[], 'guidance_chief')
        end

        has_many :measures, serializer: Api::V2::Shared::MeasureSerializer
      end
    end
  end
end
