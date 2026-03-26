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

      def send_email
        return head :not_found unless report.supports_email?

        report.send_email!

        head :accepted
      end

      def backfill
        report_definition = Reporting::AdminReportRegistry.all.find { |definition| definition.id == params[:id].to_s }
        return head :not_found unless report_definition&.id == 'differences'

        Reporting::BackfillDifferencesReports.new.call

        head :accepted
      end

      private

      def report
        @report ||= Reporting::AdminReportRegistry.fetch!(params[:id])
      end
    end
  end
end
