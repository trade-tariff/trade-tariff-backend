module Api
  module Admin
    class LiveIssuesController < AdminController

      def index
        render json: serialize(live_issues)
      end

      def create
        live_issue = LiveIssue.new(live_issue_params)

        if live_issue.valid? && live_issue.save
          render json: serialize(live_issue), status: :created
        else
          render json: serialize_errors(live_issue), status: :unprocessable_entity
        end
      end

      def update
        live_issue = LiveIssue.with_pk!(params[:id])

        if live_issue.update(live_issue_params)
          render json: serialize(live_issue)
        else
          render json: serialize_errors(live_issue), status: :unprocessable_entity
        end
      end

      private

        def live_issues
          @live_issues ||= LiveIssue.all
        end

        def live_issue_params
          params.require(:live_issue).permit(
            :title,
            :description,
            :suggested_action,
            :status,
            :date_discovered,
            :date_resolved,
            { commodities: [] }
          )
        end

        def serialize(*args)
          Api::Admin::LiveIssueSerializer.new(*args).serializable_hash
        end

        def serialize_errors(live_issue)
          Api::Admin::ErrorSerializationService.new(live_issue).call
        end
    end
  end
end
