module Api
  module Beta
    class SubheadingSerializer < GoodsNomenclatureSerializer
      set_type :subheading

      attributes :chapter_description,
                 :chapter_id,
                 :heading_description,
                 :heading_id
    end
  end
end
