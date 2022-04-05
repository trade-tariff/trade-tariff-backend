module Api
  module V2
    module Certificates
      class CertificateListSerializer
        include JSONAPI::Serializer

        set_type :certificate

        set_id :id

        attributes :certificate_type_code, :certificate_code, :description, :formatted_description

        attribute :certificate_type_description do |certificate|
          certificate.certificate_type_description&.description
        end

        attribute :validity_start_date do |certificate|
          certificate.certificate_description_period.validity_start_date
        end

        attribute :guidance_cds do |certificate|
          if TradeTariffBackend.uk?
            guidance = TradeTariffBackend.chief_cds_guidance.guidance_for("#{certificate.certificate_type_code}#{certificate.certificate_code}")

            guidance.try(:[], 'guidance_cds')
          end
        end

        attribute :guidance_chief do |certificate|
          if TradeTariffBackend.uk?
            guidance = TradeTariffBackend.chief_cds_guidance.guidance_for("#{certificate.certificate_type_code}#{certificate.certificate_code}")

            guidance.try(:[], 'guidance_chief')
          end
        end
      end
    end
  end
end
