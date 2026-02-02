class PopulateChangesTableWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    ChangesTablePopulator.populate
    ChangesTablePopulator.cleanup_outdated

    if TradeTariffBackend.uk?
      TariffChangesService.generate

      TariffChangesJobStatus.pending_emails.each do |date|
        MyCommoditiesSubscriptionWorker.perform_async(date.to_s)
      end

      RefreshActiveCommoditiesCacheWorker.perform_async
    end
  end
end
