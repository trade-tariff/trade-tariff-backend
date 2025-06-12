module Api
  module V2
    class LiveIssuesController < ApiController
      def index
        if params[:filter].present?
          render json: serialize(live_issues.where(permitted_filter).all) and return
        end

        render json: serialize(live_issues.all)
      end

      private

        def live_issues
          @live_issues ||= LiveIssue.dataset
        end

        def serialize(*args)
          Api::V2::LiveIssueSerializer.new(*args).serializable_hash
        end

        def serialize_errors(live_issue)
          Api::V2::ErrorSerializationService.new(live_issue).call
        end

        def permitted_filter
          params.require(:filter).permit(:status).to_h.symbolize_keys
        end
    end
  end
end
