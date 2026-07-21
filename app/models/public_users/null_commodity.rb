module PublicUsers
  class NullCommodity < NullObject
    attr_reader :goods_nomenclature_item_id,
                :validity_end_date,
                :chapter_short_code,
                :heading

    def initialize(goods_nomenclature_item_id:)
      super()
      @goods_nomenclature_item_id = goods_nomenclature_item_id
    end

    def id
      "null_#{goods_nomenclature_item_id}"
    end

    def classification_description
      ''
    end
  end
end
