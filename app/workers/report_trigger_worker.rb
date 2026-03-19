class ReportTriggerWorker
  include Sidekiq::Worker

  sidekiq_options retry: false

  def perform(report_id)
    report = Reporting::AdminReportRegistry.fetch!(report_id)
    report.report_class.generate
  end
end
