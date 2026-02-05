module SearchResultTracking
  extend ActiveSupport::Concern

  private

  def track_result_selected
    return if params[:request_id].blank?

    ::Search::Instrumentation.result_selected(
      request_id: params[:request_id],
      goods_nomenclature_item_id: params[:id],
      goods_nomenclature_class: controller_name.classify,
    )
  end
end
