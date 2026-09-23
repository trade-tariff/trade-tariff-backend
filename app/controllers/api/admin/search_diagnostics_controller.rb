module Api
  module Admin
    class SearchDiagnosticsController < AdminController
      def index
        correlation = SearchDiagnostics::RelatedRequests.for_filter(
          browser_session_id: params[:browser_session_id],
          experiment: params[:experiment],
          lookback_hours: params[:lookback_hours],
        )

        render json: Api::Admin::SearchDiagnosticRequestSerializer.new(
          correlation.requests,
          is_collection: true,
        ).serializable_hash
      rescue SearchDiagnostics::RequestLogLookup::QueryError, Aws::Errors::ServiceError => e
        render json: error_response(e.message, status: :bad_gateway), status: :bad_gateway
      rescue ArgumentError => e
        render json: error_response(e.message, status: :unprocessable_content), status: :unprocessable_content
      end

      def show
        result = SearchDiagnostics::RequestLogLookup.call(
          request_id: params[:request_id],
          lookback_hours: params[:lookback_hours],
          limit: params[:limit],
        )
        correlation = SearchDiagnostics::RelatedRequests.for_search_request(
          request_id: params[:request_id],
          lookback_hours: params[:lookback_hours],
        )
        diagnostic = SearchDiagnostics::Diagnostic.compose(result, correlation)

        render json: Api::Admin::SearchDiagnosticSerializer.new(diagnostic).serializable_hash
      rescue SearchDiagnostics::RequestLogLookup::QueryError, Aws::Errors::ServiceError => e
        render json: error_response(e.message, status: :bad_gateway), status: :bad_gateway
      rescue ArgumentError => e
        render json: error_response(e.message, status: :unprocessable_content), status: :unprocessable_content
      end

    private

      def error_response(message, status:)
        {
          errors: [
            {
              status: Rack::Utils.status_code(status).to_s,
              title: 'Search diagnostics unavailable',
              detail: message,
            },
          ],
        }
      end
    end
  end
end
