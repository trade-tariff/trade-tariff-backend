class SearchSuggestionPopulatorService
  def call
    SearchSuggestion.unrestrict_primary_key
    TimeMachine.now do
      suggestions = SuggestionsService.new.call
      suggestions = suggestions.uniq { |suggestion| [suggestion[:id], suggestion[:value]] }

      suggestions.each_slice(5000) do |values|
        SearchSuggestion.dataset.insert_conflict(
          constraint: :search_suggestions_pkey,
          update: {
            value: Sequel[:excluded][:value],
            type: Sequel[:excluded][:type],
            goods_nomenclature_sid: Sequel[:excluded][:goods_nomenclature_sid],
            goods_nomenclature_class: Sequel[:excluded][:goods_nomenclature_class],
            priority: Sequel[:excluded][:priority],
            updated_at: Sequel[:excluded][:updated_at],
          },
        ).multi_insert(values)
      end

      clear_old_suggestions
    end
    SearchSuggestion.restrict_primary_key
  end

  private

  def clear_old_suggestions
    candidate_goods_nomenclature_sids = SearchSuggestion.goods_nomenclature_type.select_map(:id)

    all_goods_nomenclature_sids = GoodsNomenclature
      .where(goods_nomenclature_sid: candidate_goods_nomenclature_sids)
      .select_map(:goods_nomenclature_sid)

    current_goods_nomenclature_sids = GoodsNomenclature
      .where(goods_nomenclature_sid: all_goods_nomenclature_sids)
      .actual
      .select_map(:goods_nomenclature_sid)

    expired_goods_nomenclature_sids = all_goods_nomenclature_sids - current_goods_nomenclature_sids

    SearchSuggestion
      .where(id: expired_goods_nomenclature_sids.map(&:to_s))
      .delete
  end
end
