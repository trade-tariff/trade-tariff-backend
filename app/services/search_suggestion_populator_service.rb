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
      clear_duplicate_goods_nomenclature_suggestions
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
      .delete
  end

  # A search suggestion is unique based on its input id and value
  #
  # Sometimes the value for a given goods nomenclature can change due to it moving about the hierarchy (e.g. a Subheading becomes a Commodity or a Commodity becomes a Subheading)
  # and we end up with two records that are unique based on their id (sid) but different values
  #
  # This method handles these movements by identifying and deleting the older records
  # whilst preserving the newer records.
  #
  # We only ever assume that the most recent record is the correct one since the suggestions do not support the concept
  # of the time machine currently.
  def clear_duplicate_goods_nomenclature_suggestions
    rows_to_delete = SearchSuggestion.duplicates_by(:id)
      .all
      .map do |row|
        { id: row[:id], value: row[:value] }
      end

    Rails.logger.info "Deleting #{rows_to_delete.count} duplicate suggestions\n#{JSON.pretty_generate(rows_to_delete)}"

    return if rows_to_delete.none?

    delete_condition = Sequel.|(
      *rows_to_delete.map do |row|
        Sequel.&({ id: row[:id] }, { value: row[:value] })
      end,
    )

    SearchSuggestion
      .where(delete_condition)
      .delete
  end
end
