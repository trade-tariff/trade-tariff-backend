module Api
  module Beta
    class CommoditySerializer < GoodsNomenclatureSerializer
      set_type :commodity

      attributes :chapter_description,
                 :chapter_id,
                 :heading_description,
                 :heading_id
    end
  end
end
