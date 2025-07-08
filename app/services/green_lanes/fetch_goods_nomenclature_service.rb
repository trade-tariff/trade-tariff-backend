module GreenLanes
  class FetchGoodsNomenclatureService
    ITEM_ID_LENGTH = 10

    ASSESSMENT_EAGER = [
      :theme,
      :base_regulation,
      :modification_regulation,
      :exemptions,
      { measure_type: %i[measure_type_description measure_type_series_description] },
    ].freeze

    GN_EAGER_LOAD = {
      measures: {
        additional_code: :additional_code_descriptions,
        footnotes: :footnote_descriptions,
        geographical_area: %i[geographical_area_descriptions contained_geographical_areas],
        measure_excluded_geographical_areas: [],
        excluded_geographical_areas: [
          :geographical_area_descriptions,
          :contained_geographical_areas,
          { referenced: :contained_geographical_areas },
        ],
        measure_conditions: { certificate: %i[certificate_descriptions exempting_certificate_override] },
        category_assessment: ASSESSMENT_EAGER,
        base_regulation: [],
        modification_regulation: [],
        measure_type: %i[measure_type_description measure_type_series_description],
      },
      green_lanes_measures: {
        category_assessment: ASSESSMENT_EAGER,
      },
      goods_nomenclature_descriptions: [],
    }.freeze

    EAGER_LOAD = {
      ancestors: GN_EAGER_LOAD,
      descendants: GN_EAGER_LOAD,
    }.merge(GN_EAGER_LOAD).freeze

    def initialize(goods_nomenclature_item_id)
      @goods_nomenclature_item_id = goods_nomenclature_item_id
    end

    def call
      if invalid_id(@goods_nomenclature_item_id)
        raise Sequel::RecordNotFound
      end

      if is_id_length_greater(@goods_nomenclature_item_id, 4) || declarable?
        GoodsNomenclature
          .actual
          .eager(EAGER_LOAD)
          .where(goods_nomenclature_item_id: length_adjusted_digit_id)
          .take
      else
        raise Sequel::RecordNotFound
      end
    end

    private

    def declarable?
      gn = GoodsNomenclature
             .actual
             .association_inner_join(goods_nomenclature_indents: proc { |ds| ds.with_actual(GoodsNomenclatureIndent, self) })
             .where(Sequel[:goods_nomenclatures][:goods_nomenclature_item_id] => length_adjusted_digit_id)
             .order(Sequel[:goods_nomenclatures][:producline_suffix], Sequel[:goods_nomenclature_indents][:number_indents])
             .first

      gn.present? && gn.declarable?
    end

    def invalid_id(id)
      id.blank? || !is_id_length_greater(id, 2)
    end

    def is_id_length_greater(id, length)
      id.length > length && id[length..].each_char.any? { |char| char != '0' }
    end

    def length_adjusted_digit_id
      @goods_nomenclature_item_id.ljust(ITEM_ID_LENGTH, '0')
    end
  end
end
