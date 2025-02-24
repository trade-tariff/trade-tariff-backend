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
                   :guidance_cds
        #  :guidance_chief

        has_one :goods_nomenclatures,
                serializer: proc { |record, _params|
                  if record && record.respond_to?(:goods_nomenclature_class)
                    "Api::V2::Shared::#{record.goods_nomenclature_class}Serializer".constantize
                  else
                    Api::V2::Shared::GoodsNomenclatureSerializer
                  end
                }
      end
    end
  end
end
