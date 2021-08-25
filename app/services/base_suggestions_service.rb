class BaseSuggestionsService
  def to_json(_config = {})
    perform.to_json
  end

  def perform
    commodities = Commodity
          .select(:goods_nomenclature_sid, :goods_nomenclature_item_id)
          .actual
          .distinct
          .order(Sequel.desc(:goods_nomenclature_item_id))
          .map { |commodity| handle_commodity_record(commodity) }

    search_references = SearchReference
          .select(:id, :title)
          .distinct
          .order(Sequel.desc(:title))
          .map { |search_reference| handle_search_reference_record(search_reference)}

    chemicals = Chemical
          .select(:id, :cas)
          .order(Sequel.desc(:cas))
          .map { |chemical| handle_chemical_record(chemical) }

    [commodities, search_references, chemicals].flatten.compact
  end

  protected

  def handle_commodity_record(_commodity)
    nil
  end

  def handle_search_reference_record(_search_reference)
    nil
  end
end
