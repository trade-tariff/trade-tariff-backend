class BaseSuggestionsService
  def to_json(_config = {})
    perform.to_json
  end

  def perform
    chapters = Chapter
      .select(:goods_nomenclature_sid, :goods_nomenclature_item_id)
      .actual
      .non_hidden
      .map { |chapter| handle_chapter_record(chapter) }

    headings = Heading
      .select(:goods_nomenclature_sid, :goods_nomenclature_item_id)
      .actual
      .non_hidden
      .map { |heading| handle_heading_record(heading) }

    commodities = Commodity
          .select(:goods_nomenclature_sid, :goods_nomenclature_item_id)
          .actual
          .non_hidden
          .map { |commodity| handle_commodity_record(commodity) }

    search_references = SearchReference
          .select(:id, :title)
          .distinct(:title)
          .order(Sequel.desc(:title))
          .map { |search_reference| handle_search_reference_record(search_reference) }

    [chapters, headings, commodities, search_references].flatten.compact
  end

  protected

  def handle_chapter_record(_chapter)
    nil
  end

  def handle_heading_record(_heading)
    nil
  end

  def handle_commodity_record(_commodity)
    nil
  end

  def handle_search_reference_record(_search_reference)
    nil
  end
end
