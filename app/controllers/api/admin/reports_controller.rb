module Api
  module Admin
    class ReportsController < AdminController
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

      private

      def report
        @report ||= Reporting::AdminReportRegistry.fetch!(params[:id])
      end
    end
  end
end
