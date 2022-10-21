module Api
  module Beta
    class GoodsNomenclatureSerializer
      include JSONAPI::Serializer

      set_type :goods_nomenclature

      attributes :goods_nomenclature_item_id,
                 :producline_suffix,
                 :formatted_description,
                 :description,
                 :description_indexed,
                 :search_references,
                 :validity_start_date,
                 :validity_end_date,
                 :chapter_id,
                 :score,
                 :declarable

      has_many :ancestors, lazy_load: true, serializer: proc { |record, _params|
        if record && record.respond_to?(:goods_nomenclature_class)
          "Api::Beta::#{record.goods_nomenclature_class}Serializer".constantize
        else
          Api::Beta::GoodsNomenclatureSerializer
        end
      }
    end
  end
end
