module Api
  module Beta
    class HeadingSerializer < GoodsNomenclatureSerializer
      set_type :heading

      attributes :chapter_description,
                 :chapter_id
    end
  end
end
