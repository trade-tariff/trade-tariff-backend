class AdditionalCodeFinderService
  def initialize(code, type, description)
    @code = code
    @type = type
    @description = description
  end

  def call
    return [] if description_additional_code_sids.empty? && code.blank? && type.blank?

    Api::V2::AdditionalCodeSearch::AdditionalCodePresenter.wrap(
      additional_codes,
      grouped_goods_nomenclatures,
    )
  end

  private

  attr_reader :code, :type, :description

  def additional_codes
    AdditionalCode
      .where(additional_code_sid: grouped_measures.keys)
      .eager(:additional_code_descriptions)
      .all
  end

  def grouped_goods_nomenclatures
    grouped_measures.transform_values do |measures|
      measures
        .map { |measure| indexed_goods_nomenclatures[measure.goods_nomenclature_sid] }
        .compact
    end
  end

  def grouped_measures
    @grouped_measures ||= Measure
      .actual
      .with_regulation_dates_query
      .with_additional_code_sid(description_additional_code_sids)
      .with_additional_code_type(type)
      .with_additional_code_id(code)
      .distinct(%i[additional_code_sid additional_code_type_id additional_code_id goods_nomenclature_sid])
      .all
      .group_by(&:additional_code_sid)
  end

  def goods_nomenclature_sids
    grouped_measures.flat_map do |_additional_code_sid, measures|
      measures.map(&:goods_nomenclature_sid)
    end
  end

  def indexed_goods_nomenclatures
    @indexed_goods_nomenclatures ||= GoodsNomenclature
      .actual
      .non_hidden
      .non_classifieds
      .with_leaf_column
      .where(goods_nomenclatures__goods_nomenclature_sid: goods_nomenclature_sids)
      .eager(:goods_nomenclature_descriptions)
      .all
      .index_by(&:goods_nomenclature_sid)
  end

  def description_additional_code_sids
    return [] if description.blank?

    AdditionalCodeDescription
      .with_fuzzy_description(description)
      .select_map(:additional_code_sid)
  end
end
