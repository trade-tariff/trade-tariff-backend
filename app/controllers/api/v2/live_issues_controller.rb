module Api
  module V2
    class LiveIssuesController < ApiController
      no_caching

      def index
        render json: serialize(filtered_live_issues), status: :ok
      rescue StandardError => e
        render json: serialize_errors(e)
      end

      private

      def live_issues
        @live_issues ||= LiveIssue.dataset
      end

      def filtered_live_issues
        return live_issues.all if params[:filter].blank?

        live_issues.where(permitted_filter).all
      end

      def serialize(*args)
        Api::V2::LiveIssueSerializer.new(*args).serializable_hash
      end

      def serialize_errors(*args)
        Api::V2::ErrorSerializationService.new(*args).call
      end

      def permitted_filter
        params.require(:filter).permit(:status).to_h.symbolize_keys
      end
    end
  end
end
