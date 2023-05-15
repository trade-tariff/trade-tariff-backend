module Api
  module V2
    module Shared
      class GoodsNomenclatureSerializer
        include JSONAPI::Serializer

        set_id :goods_nomenclature_sid

        attributes :goods_nomenclature_item_id,
                   :producline_suffix,
                   :description,
                   :formatted_description,
                   :validity_start_date,
                   :validity_end_date

        class << self
          def serializer_proc
            proc do |record, _params|
              if record.try(:goods_nomenclature_class)
                "Api::V2::Shared::#{record.goods_nomenclature_class}Serializer".constantize
              else
                Api::V2::Shared::GoodsNomenclatureSerializer
              end
            end
          end
        end
      end
    end
  end
end
