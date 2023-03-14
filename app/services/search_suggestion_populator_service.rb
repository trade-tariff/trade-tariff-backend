class SearchSuggestionPopulatorService
  def call
    SearchSuggestion.unrestrict_primary_key
    TimeMachine.now do
      Api::V2::SuggestionsService.new.perform.each do |suggestion|
        SearchSuggestion.find_or_create(
          id: suggestion.id.to_s,
          value: suggestion.value.to_s,
        )
      end

      clear_old_suggestions
    end
    SearchSuggestion.restrict_primary_key
  end

  private

  def clear_old_suggestions
    candidate_goods_nomenclature_sids = SearchSuggestion.where("id ~ '^[0-9]+$'").pluck(:id)

    all_goods_nomenclature_sids = GoodsNomenclature
      .where(goods_nomenclature_sid: candidate_goods_nomenclature_sids)
      .pluck(:goods_nomenclature_sid)

    current_goods_nomenclature_sids = GoodsNomenclature
      .where(goods_nomenclature_sid: all_goods_nomenclature_sids)
      .actual
      .pluck(:goods_nomenclature_sid)

    expired_goods_nomenclature_sids = all_goods_nomenclature_sids - current_goods_nomenclature_sids

    SearchSuggestion
      .where(id: expired_goods_nomenclature_sids.map(&:to_s))
      .map(&:destroy)
  end
end
