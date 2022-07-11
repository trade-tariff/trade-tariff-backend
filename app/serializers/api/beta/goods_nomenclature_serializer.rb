module Api
  module Beta
    class GoodsNomenclatureSerializer
      include JSONAPI::Serializer

      set_type :goods_nomenclature

      attributes :goods_nomenclature_item_id,
                 :producline_suffix,
                 :description,
                 :description_indexed,
                 :search_references,
                 :validity_start_date,
                 :validity_end_date,
                 :chapter_id,
                 :score

      has_many :ancestors, serializer: Api::Beta::AncestorSerializer
    end
  end
end
