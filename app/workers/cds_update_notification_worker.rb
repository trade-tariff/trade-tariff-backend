class CdsUpdateNotificationWorker
  include Sidekiq::Worker

  # Both of these fail the job on purpose. The spreadsheet is this job's only output, so a
  # green job with no spreadsheet is indistinguishable from a quiet day to the tariff team.
  # retry: false means the job dies on the first raise, which runs SidekiqDeathHandler (this
  # worker does not set slack_alerts: false) and is recorded by New Relic.
  class MissingNotificationError < StandardError; end
  class ReportFailedError < StandardError; end

  sidekiq_options queue: :sync, retry: false

  def perform(notification_id)
    return unless TradeTariffBackend.uk?

    notification = CdsUpdateNotification.find(id: notification_id)

    if notification.nil?
      raise MissingNotificationError, "CdsUpdateNotification #{notification_id} no longer exists, so no CDS updates spreadsheet was generated"
    end

    cds_update = notification.cds_update
    failures = generate_report(cds_update)

    return if failures.empty?

    raise ReportFailedError, "CDS updates spreadsheet for #{cds_update.filename} was not delivered: #{failures.join('; ')}"
  end

private

  # The writer cannot raise: it also runs inside the daily sync, where a broken report must
  # not fail a data import that otherwise succeeded. It announces failures instead, and this
  # worker, which has the context to decide, turns them into a dead job. Failures are matched
  # on filename so a sync running concurrently on the same queue cannot fail this job.
  def generate_report(cds_update)
    failures = []

    subscriber = ActiveSupport::Notifications.subscribe(CdsImporter::ExcelWriter::FAILURE_EVENT) do |*, payload|
      failures << payload[:message] if payload[:filename] == cds_update.filename
    end

    begin
      CdsImporter.new(cds_update, handler_classes: [CdsImporter::ExcelWriter]).import
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    failures
  end
end
