class SearchSuggestionPopulatorService
  BATCH_SIZE = 5000

  def call
    SearchSuggestion.unrestrict_primary_key
    TimeMachine.now do
      suggestions = SuggestionsService.new.call

      suggestions.each_slice(BATCH_SIZE) do |values|
        SearchSuggestion.dataset.insert_conflict(
          constraint: :search_suggestions_pkey,
          update: {
            value: Sequel[:excluded][:value],
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

  # A search suggestion always points to an associated goods nomenclature
  #
  # This goods nomenclature may expire or be replaced by a new goods nomenclature
  # and the suggestions point to now-expired goods nomenclatures
  #
  # This method clears out these expired suggestions
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

    Rails.logger.info "Deleting #{expired_goods_nomenclature_sids.count} expired suggestions"

    SearchSuggestion
      .where(id: expired_goods_nomenclature_sids.map(&:to_s))
      .goods_nomenclature_type
      .delete
  end
end
