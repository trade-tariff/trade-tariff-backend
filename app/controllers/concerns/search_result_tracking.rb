module SearchResultTracking
  extend ActiveSupport::Concern

  SEARCH_REQUEST_ID_HEADER = 'X-Search-Request-Id'.freeze

  private

  def track_result_selected
    rid = search_request_id
    return if rid.blank?

    ::Search::Instrumentation.result_selected(
      request_id: rid,
      goods_nomenclature_item_id: params[:id],
      goods_nomenclature_class: controller_name.classify,
    )
  end

  def search_request_id
    request.headers[SEARCH_REQUEST_ID_HEADER].presence || params[:request_id].presence
  end
end
