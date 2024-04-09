module GreenLanes
  class FetchGoodsNomenclatureService
    ITEM_ID_LENGTH = 10

    MEASURES_EAGER = {
      additional_code: :additional_code_descriptions,
      goods_nomenclature: %i[goods_nomenclature_indents goods_nomenclature_descriptions],
      footnotes: :footnote_descriptions,
      geographical_area: %i[geographical_area_descriptions contained_geographical_areas],
      measure_excluded_geographical_areas: [],
      excluded_geographical_areas: :geographical_area_descriptions,
      measure_conditions: { certificate: :certificate_descriptions },
      category_assessment: :theme,
    }.freeze

    EAGER_LOAD = {
      ancestors: {
        measures: MEASURES_EAGER,
        goods_nomenclature_descriptions: [],
      },
      descendants: {
        measures: MEASURES_EAGER,
        goods_nomenclature_descriptions: [],
      },
      measures: MEASURES_EAGER,
      goods_nomenclature_descriptions: [],
    }.freeze

    def initialize(goods_nomenclature_item_id)
      @goods_nomenclature_item_id = goods_nomenclature_item_id
    end

    def call
      GoodsNomenclature
        .actual
        .eager(EAGER_LOAD)
        .where(goods_nomenclature_item_id: length_adjusted_digit_id, producline_suffix: '80')
        .take
    end

    private

    def length_adjusted_digit_id
      @goods_nomenclature_item_id.ljust(ITEM_ID_LENGTH, '0')
    end
  end
end
