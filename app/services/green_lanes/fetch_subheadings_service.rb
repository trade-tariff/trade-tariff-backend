module GreenLanes
  class FetchSubheadingsService
    ITEM_ID_LENGTH = 10
    def initialize(goods_nomenclature_item_id)
      @goods_nomenclature_item_id = goods_nomenclature_item_id
    end

    def call
      subheading = Subheading
        .actual
        .where(goods_nomenclature_item_id: length_adjusted_digit_id, producline_suffix: '80')
        .take

      SubheadingMeasures.new(subheading, subheading.applicable_measures)
    end

    private

    def length_adjusted_digit_id
      @goods_nomenclature_item_id.ljust(ITEM_ID_LENGTH, '0')
    end
  end
end
