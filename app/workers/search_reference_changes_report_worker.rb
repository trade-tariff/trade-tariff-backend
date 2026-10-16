class SearchReferenceChangesReportWorker
  include Sidekiq::Worker

  sidekiq_options retry: 1

  sidekiq_retry_in { 1.hour.to_i }

  def perform(deliver_email: true)
    result = Reporting::SearchReferenceChanges.generate
    ReportsMailer.search_reference_changes(result).deliver_now if deliver_email
  end
end
