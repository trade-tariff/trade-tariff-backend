module Api
  module V2
    class LiveIssuesController < ApiController
      def index
        render json: serialize(live_issues)
      end

      private

        def live_issues
          @live_issues ||= LiveIssue.all
        end

        def serialize(*args)
          Api::V2::LiveIssueSerializer.new(*args).serializable_hash
        end
    end
  end
end
