module GreenLanes
  class FetchGoodsNomenclatureService
    ITEM_ID_LENGTH = 10
    def initialize(goods_nomenclature_item_id)
      @goods_nomenclature_item_id = goods_nomenclature_item_id
    end

    def call
      GoodsNomenclature
        .actual
        .where(goods_nomenclature_item_id: length_adjusted_digit_id, producline_suffix: '80')
        .take
    end

    private

    def length_adjusted_digit_id
      @goods_nomenclature_item_id.ljust(ITEM_ID_LENGTH, '0')
    end
  end
end
