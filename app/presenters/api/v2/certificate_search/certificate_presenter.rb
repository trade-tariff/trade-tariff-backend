module Api
  module V2
    module CertificateSearch
      class CertificatePresenter < WrapDelegator
        def self.wrap(certificates, grouped_goods_nomenclatures)
          certificates.map do |certificate|
            key = "#{certificate.certificate_type_code}#{certificate.certificate_code}"
            goods_nomenclatures = grouped_goods_nomenclatures[key] || []

            new(certificate, goods_nomenclatures)
          end
        end

        attr_reader :goods_nomenclatures

        def initialize(certificate, goods_nomenclatures)
          super(certificate)

          @certificate = certificate
          @goods_nomenclatures = goods_nomenclatures
        end

        def goods_nomenclature_ids
          goods_nomenclatures.map(&:goods_nomenclature_sid)
        end
      end
    end
  end
end
