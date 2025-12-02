module PublicUsers
  class NullCommodity
    attr_reader :goods_nomenclature_item_id

    def initialize(goods_nomenclature_item_id:)
      @goods_nomenclature_item_id = goods_nomenclature_item_id
    end

    def id
      "null_#{goods_nomenclature_item_id}"
    end

    def classification_description
      ''
    end

    def validity_end_date
      nil
    end

    def chapter_short_code
      nil
    end

    def heading
      nil
    end
  end
end
