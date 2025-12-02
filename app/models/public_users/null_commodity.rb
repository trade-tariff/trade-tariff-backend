module PublicUsers
  class NullCommodity
    attr_reader :goods_nomenclature_item_id, :invalid

    def initialize(goods_nomenclature_item_id:, invalid: true)
      @goods_nomenclature_item_id = goods_nomenclature_item_id
      @invalid = invalid
    end

    def id
      goods_nomenclature_item_id
    end
  end
end
