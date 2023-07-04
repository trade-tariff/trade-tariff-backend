class SuggestionsService
  def call
    SearchSuggestion.unrestrict_primary_key
    suggestions = TimeMachine.now do
      [
        build_goods_nomenclatures_search_suggestions,
        build_search_references_search_suggestions,
        build_full_chemicals_search_suggestions,
        build_full_chemicals_cas_search_suggestions,
        build_full_chemicals_cus_search_suggestions,
      ].flatten.compact
    end
    SearchSuggestion.restrict_primary_key

    suggestions
  end

  private

  def build_goods_nomenclatures_search_suggestions
    GoodsNomenclature
      .actual
      .non_hidden
      .with_leaf_column
      .map { |goods_nomenclature| build_goods_nomenclature_record(goods_nomenclature) }
  end

  def build_search_references_search_suggestions
    SearchReference
      .select(:id, :title, :goods_nomenclature_sid, :referenced_class)
      .eager(referenced: :ns_children)
      .distinct(:title)
      .order(Sequel.desc(:title))
      .all
      .map { |search_reference| build_search_reference_record(search_reference) }
  end

  def build_full_chemicals_search_suggestions
    full_chemicals.map { |full_chemical| build_name_chemical_record(full_chemical) }
  end

  def build_full_chemicals_cas_search_suggestions
    full_chemicals.map { |full_chemical| build_cas_chemical_record(full_chemical) }
  end

  def build_full_chemicals_cus_search_suggestions
    full_chemicals.map { |full_chemical| build_cus_chemical_record(full_chemical) }
  end

  def full_chemicals
    @full_chemicals ||= FullChemical.eager(goods_nomenclature: :ns_children).all
  end

  def build_search_reference_record(search_reference)
    SearchSuggestion.build(
      id: search_reference.id,
      value: search_reference.title.downcase,
      type: SearchSuggestion::TYPE_SEARCH_REFERENCE,
      goods_nomenclature_sid: search_reference.goods_nomenclature_sid,
      goods_nomenclature_class: search_reference.referenced.goods_nomenclature_class,
      created_at: now,
      updated_at: now,
    )
  end

  def build_goods_nomenclature_record(goods_nomenclature)
    return nil if goods_nomenclature.heading? && goods_nomenclature.grouping?

    SearchSuggestion.build(
      id: goods_nomenclature.goods_nomenclature_sid,
      value: goods_nomenclature.short_code,
      type: SearchSuggestion::TYPE_GOODS_NOMENCLATURE,
      goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
      goods_nomenclature_class: goods_nomenclature.goods_nomenclature_class,
      created_at: now,
      updated_at: now,
    )
  end

  def build_name_chemical_record(full_chemical)
    return nil if full_chemical.goods_nomenclature.blank?
    return nil if full_chemical.name.blank?

    SearchSuggestion.build(
      id: full_chemical.cus,
      value: full_chemical.name.downcase,
      type: SearchSuggestion::TYPE_FULL_CHEMICAL_NAME,
      goods_nomenclature_sid: full_chemical.goods_nomenclature_sid,
      goods_nomenclature_class: full_chemical.goods_nomenclature.goods_nomenclature_class,
      created_at: now,
      updated_at: now,
    )
  end

  def build_cus_chemical_record(full_chemical)
    return nil if full_chemical.goods_nomenclature.blank?

    SearchSuggestion.build(
      id: full_chemical.cus,
      value: full_chemical.cus,
      type: SearchSuggestion::TYPE_FULL_CHEMICAL_CUS,
      goods_nomenclature_sid: full_chemical.goods_nomenclature_sid,
      goods_nomenclature_class: full_chemical.goods_nomenclature.goods_nomenclature_class,
      created_at: now,
      updated_at: now,
    )
  end

  def build_cas_chemical_record(full_chemical)
    return nil if full_chemical.goods_nomenclature.blank?
    return nil if full_chemical.cas_rn.blank?

    SearchSuggestion.build(
      id: full_chemical.cus,
      value: full_chemical.cas_rn,
      type: SearchSuggestion::TYPE_FULL_CHEMICAL_CAS,
      goods_nomenclature_sid: full_chemical.goods_nomenclature_sid,
      goods_nomenclature_class: full_chemical.goods_nomenclature.goods_nomenclature_class,
      created_at: now,
      updated_at: now,
    )
  end

  def now
    @now ||= Time.zone.now
  end
end
