module Api
  module Admin
    class SearchAnalyticsController < AdminController
      def index
        period = ::SearchAnalytics::Period.for(period: params[:period], view: params[:view])
        date_range = if params.key?(:from) || params.key?(:to) || params[:period] == 'custom'
                       ::SearchAnalytics::DateRange.parse(from: params[:from], to: params[:to])
                     end
        result = ::SearchAnalytics::DailyResults.call(
          period:, date_range:, region: ENV.fetch('AWS_REGION', ENV.fetch('AWS_DEFAULT_REGION', 'eu-west-2')),
        )

        if result
          render json: Api::Admin::SearchAnalyticsSerializer.new(result).serializable_hash
        else
          render json: error_response('Search analytics unavailable', 'No complete stored daily query results are available for this period.', :not_found), status: :not_found
        end
      rescue ::SearchAnalytics::DateRange::InvalidRange => e
        render json: error_response('Invalid date range', e.message, :bad_request), status: :bad_request
      end

    private

      def error_response(title, detail, status)
        { errors: [{ status: Rack::Utils.status_code(status).to_s, title:, detail: }] }
      end
    end
  end
end
