module Api
  module Admin
    class LiveIssuesController < AdminController
      def index
        render json: serialize(live_issues)
      end

      def show
        render json: serialize(LiveIssue.with_pk!(params[:id]))
      end

      def create
        live_issue = LiveIssue.new(live_issue_params)

        if live_issue.valid? && live_issue.save
          render json: serialize(live_issue), status: :created
        else
          render json: serialize_errors(live_issue), status: :unprocessable_content
        end
      end

      def update
        live_issue = LiveIssue.with_pk!(params[:id])

        live_issue.update(live_issue_params)
        render json: serialize(live_issue), status: :ok
      rescue Sequel::ValidationFailed
        render json: serialize_errors(live_issue), status: :unprocessable_content
      end

      def destroy
        live_issue = LiveIssue.with_pk!(params[:id])
        live_issue.destroy

        head :no_content
      end

      private

      def serializer_class = Api::Admin::LiveIssueSerializer

      def live_issues
        @live_issues ||= LiveIssue.all
      end

      def live_issue_params
        attributes = params.require(:data).require(:attributes)

        permitted_params = attributes.permit(
          :title,
          :description,
          :suggested_action,
          :status,
          :date_discovered,
          :date_resolved,
        )

        if attributes.key?(:commodities)
          permitted_params.merge(commodities: normalized_commodities(attributes[:commodities]))
        else
          permitted_params
        end
      end

      def normalized_commodities(commodities)
        return [] if commodities.blank?

        return [nil] unless commodities.is_a?(String) || commodities.is_a?(Array)

        Array(commodities).flat_map do |commodity|
          return [nil] unless commodity.is_a?(String)

          commodity.split(/[,\s]+/)
        end
      end
    end
  end
end
