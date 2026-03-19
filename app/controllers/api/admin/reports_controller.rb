module Api
  module Admin
    class ReportsController < AdminController
      include AdminApi.routes.url_helpers

      def index
        reports = Reporting::AdminReportRegistry.all

        render json: Api::Admin::ReportSerializer.new(reports).serializable_hash
      end

      def show
        render json: Api::Admin::ReportSerializer.new(report).serializable_hash
      end

      def run
        ReportTriggerWorker.perform_async(report.id)

        head :accepted
      end

      def download
        return head :not_found unless report.available_today?

        redirect_to report.download_link_today, allow_other_host: true
      end

      private

      def report
        @report ||= Reporting::AdminReportRegistry.fetch!(params[:id])
      end
    end
  end
end
