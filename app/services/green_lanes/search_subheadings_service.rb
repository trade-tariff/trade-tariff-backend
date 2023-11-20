module GreenLanes
  class SearchSubheadingsService
    def initialize(goods_nomenclature_item_id)
      @goods_nomenclature_item_id = goods_nomenclature_item_id
    end

    def call
      Subheading
        .actual
        .where(goods_nomenclature_item_id: "#{@goods_nomenclature_item_id}0000", producline_suffix: '80')
        .take
    end
  end
end
