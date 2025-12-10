class PopulateChangesTableWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    ChangesTablePopulator.populate
    ChangesTablePopulator.cleanup_outdated

    TariffChangesService.generate
    MyCommoditiesSubscriptionWorker.perform_async

    date = Time.zone.yesterday
    package = TariffChangesService.generate_report_for(date)
    ReportsMailer.commodity_watchlist(date, package).deliver_now
  end
end
