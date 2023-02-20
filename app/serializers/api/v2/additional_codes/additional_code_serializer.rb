module Api
  module V2
    module AdditionalCodes
      class AdditionalCodeSerializer
        include JSONAPI::Serializer

        set_type :additional_code

        set_id :additional_code_sid

        attributes :additional_code_type_id,
                   :additional_code,
                   :code,
                   :description,
                   :formatted_description

        has_many :goods_nomenclatures,
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
