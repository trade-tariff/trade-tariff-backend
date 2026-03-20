class ReportTriggerWorker
  include Sidekiq::Worker

  sidekiq_options queue: :within_1_hour, retry: 3

  def perform(report_id)
    report = Reporting::AdminReportRegistry.fetch!(report_id)
    report.report_class.generate
  end
end
