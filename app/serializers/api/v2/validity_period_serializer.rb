module Api
  module V2
    class ValidityPeriodSerializer
      include JSONAPI::Serializer

      set_type :validity_period

      attributes :goods_nomenclature_item_id,
                 :producline_suffix,
                 :validity_start_date,
                 :validity_end_date,
                 :description,
                 :formatted_description,
                 :to_param

      has_many :deriving_goods_nomenclatures,
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
