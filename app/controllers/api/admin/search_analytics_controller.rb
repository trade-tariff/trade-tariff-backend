module Api
  module Admin
    class SearchAnalyticsController < AdminController
      def index
        period = ::SearchAnalytics::Period.for(period: params[:period], view: params[:view])
        snapshot = SearchAnalyticsSnapshot.latest_for(
          service: TradeTariffBackend.service,
          period: period.key,
          view: period.view,
        )

        if snapshot
          render json: Api::Admin::SearchAnalyticsSerializer.new(snapshot).serializable_hash
        else
          render json: error_response(period), status: :not_found
        end
      end

      private

      def error_response(period)
        {
          errors: [{
            status: '404',
            title: 'Search analytics unavailable',
            detail: "No cached search analytics snapshot is available for #{period.key}/#{period.view}",
          }],
        }
      end
    end
  end
end
