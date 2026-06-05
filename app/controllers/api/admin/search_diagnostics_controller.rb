module Api
  module Admin
    class SearchDiagnosticsController < AdminController
      def show
        diagnostic = SearchDiagnostics::RequestLogLookup.call(
          request_id: params[:request_id],
          lookback_hours: params[:lookback_hours],
          limit: params[:limit],
        )

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
