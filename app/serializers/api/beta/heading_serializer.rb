module Api
  module Beta
    class HeadingSerializer < GoodsNomenclatureSerializer
      set_type :heading

      attributes :chapter_description,
                 :chapter_id

      has_many :guides, serializer: Api::Beta::GuideSerializer
    end
  end
end
