module Api
  module Beta
    class ChapterSerializer < GoodsNomenclatureSerializer
      set_type :chapter

      has_many :guides, serializer: Api::Beta::GuideSerializer
    end
  end
end
