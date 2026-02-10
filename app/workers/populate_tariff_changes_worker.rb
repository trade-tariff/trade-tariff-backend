class PopulateTariffChangesWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  # Populates tariff changes for MyOTT
  def perform
    return unless TradeTariffBackend.uk?

    TariffChangesService.generate

    TariffChangesJobStatus.pending_emails.each do |date|
      MyCommoditiesSubscriptionWorker.perform_async(date.to_s)
    end

    RefreshActiveCommoditiesCacheWorker.perform_async
  end
end
