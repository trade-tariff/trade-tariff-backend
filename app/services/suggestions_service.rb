class SuggestionsService
  def call
    SearchSuggestion.unrestrict_primary_key

    chapters = Chapter
      .select(:goods_nomenclature_sid, :goods_nomenclature_item_id)
      .actual
      .non_hidden
      .map { |chapter| handle_goods_nomenclature_record(chapter) }

    headings = Heading
      .select(:goods_nomenclature_sid, :goods_nomenclature_item_id)
      .actual
      .non_hidden
      .map { |heading| handle_goods_nomenclature_record(heading) }

    commodities = Commodity
      .select(:goods_nomenclature_sid, :goods_nomenclature_item_id)
      .actual
      .non_hidden
      .map { |commodity| handle_goods_nomenclature_record(commodity) }

    search_references = SearchReference
      .select(:id, :title, :goods_nomenclature_sid)
      .distinct(:title)
      .order(Sequel.desc(:title))
      .map { |search_reference| handle_search_reference_record(search_reference) }

    full_chemicals = FullChemical.all

    full_chemicals_cus = full_chemicals.map { |full_chemical| handle_cus_chemical_record(full_chemical) }
    full_chemicals_cas = full_chemicals.map { |full_chemical| handle_cas_chemical_record(full_chemical) }
    full_chemicals_name = full_chemicals.map { |full_chemical| handle_name_chemical_record(full_chemical) }

    SearchSuggestion.restrict_primary_key

    [
      chapters,
      headings,
      commodities,
      search_references,
      full_chemicals_cas,
      full_chemicals_cus,
      full_chemicals_name,
    ].flatten.compact
  end

  private

  def handle_search_reference_record(search_reference)
    SearchSuggestion.new(
      id: search_reference.id,
      value: search_reference.title,
      priority: 1,
      type: SearchSuggestion::TYPE_SEARCH_REFERENCE,
      goods_nomenclature_sid: search_reference.goods_nomenclature_sid,
      created_at: now,
      updated_at: now,
    )
  end

  def handle_goods_nomenclature_record(goods_nomenclature)
    SearchSuggestion.new(
      id: goods_nomenclature.goods_nomenclature_sid,
      value: goods_nomenclature.short_code,
      priority: 2,
      type: SearchSuggestion::TYPE_GOODS_NOMENCLATURE,
      goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
      created_at: now,
      updated_at: now,
    )
  end

  def handle_name_chemical_record(full_chemical)
    return nil if full_chemical.name.blank?

    SearchSuggestion.new(
      id: full_chemical.cus,
      value: full_chemical.name.downcase,
      priority: 3,
      type: SearchSuggestion::TYPE_FULL_CHEMICAL_NAME,
      goods_nomenclature_sid: full_chemical.goods_nomenclature_sid,
      created_at: now,
      updated_at: now,
    )
  end

  def handle_cus_chemical_record(full_chemical)
    SearchSuggestion.new(
      id: full_chemical.cus,
      value: full_chemical.cus,
      priority: 3,
      type: SearchSuggestion::TYPE_FULL_CHEMICAL_CUS,
      goods_nomenclature_sid: full_chemical.goods_nomenclature_sid,
      created_at: now,
      updated_at: now,
    )
  end

  def handle_cas_chemical_record(full_chemical)
    return nil if full_chemical.cas_rn.blank?

    SearchSuggestion.new(
      id: full_chemical.cus,
      value: full_chemical.cas_rn,
      priority: 4,
      type: SearchSuggestion::TYPE_FULL_CHEMICAL_CAS,
      goods_nomenclature_sid: full_chemical.goods_nomenclature_sid,
      created_at: now,
      updated_at: now,
    )
  end

  def now
    @now ||= Time.zone.now
  end
end
