module Api
  module Beta
    class GoodsNomenclatureQuerySerializer
      include JSONAPI::Serializer
      set_type :goods_nomenclature_query

      attributes :query
    end
  end
end
