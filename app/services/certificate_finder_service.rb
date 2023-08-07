class CertificateFinderService
  def initialize(type, code, description)
    @type = type
    @code = code
    @description = description
  end

  def call
    return [] if description_types_and_codes.empty? && (type.blank? || code.blank?)

    Api::V2::CertificateSearch::CertificatePresenter.wrap(
      certificates,
      grouped_goods_nomenclatures,
    )
  end

  private

  attr_reader :type, :code, :description

  def certificates
    return [] if grouped_measures.none?

    all_certificate_codes = grouped_measures.keys.map do |certificate_full_code|
      [certificate_full_code[0], certificate_full_code[1...]]
    end

    Certificate
      .with_certificate_types_and_codes(all_certificate_codes)
      .eager(
        :certificate_descriptions,
        :appendix_5a,
      )
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
      .with_all_measure_conditions
      .with_certificate_type_code(type)
      .with_certificate_code(code)
      .with_certificate_types_and_codes(description_types_and_codes)
      .distinct(%i[measure_conditions__certificate_type_code measure_conditions__certificate_code measures__goods_nomenclature_sid])
      .select_append(:measure_conditions__certificate_type_code, :measure_conditions__certificate_code)
      .all
      .group_by do |measure|
        "#{measure[:certificate_type_code]}#{measure[:certificate_code]}"
      end
  end

  def goods_nomenclature_sids
    grouped_measures.flat_map do |_certicate_full_code, measures|
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

  def description_types_and_codes
    return [] if description.blank?

    CertificateDescription
      .with_fuzzy_description(description)
      .select_map(%i[certificate_type_code certificate_code])
  end
end
