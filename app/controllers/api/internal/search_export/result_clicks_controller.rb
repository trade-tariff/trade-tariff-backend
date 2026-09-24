# frozen_string_literal: true

module Api
  module Internal
    module SearchExport
      class ResultClicksController < InternalController
        def create
          return head :not_found unless TradeTariffBackend.uk?
          return head :forbidden unless TradeTariffRequest.request_source == TradeTariffRequest::FRONTEND_REQUEST_SOURCE

          click = ::SearchExport::ResultClick.record(
            request_id: params[:request_id].to_s,
            commodity_code: params[:goods_nomenclature_item_id],
            result_rank: params[:result_rank],
          )
          return head :unprocessable_content unless click

          head :no_content
        end
      end
    end
  end
end
