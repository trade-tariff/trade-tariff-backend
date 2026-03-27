module TradeTariffBackend
  module TariffUpdateEventListener
    TARIFF_UPDATES_APPLIED = 'tariff_updates_applied.tariff_synchronizer'.freeze
    TARIFF_CACHE_CLEARED   = 'tariff_cache_cleared.tariff_synchronizer'.freeze

    def self.subscribe!
      ActiveSupport::Notifications.subscribe(TARIFF_UPDATES_APPLIED) do |*, payload|
        on_tariff_updates_applied(payload)
      end

      ActiveSupport::Notifications.subscribe(TARIFF_CACHE_CLEARED) do |*, payload|
        on_tariff_cache_cleared(payload)
      end
    end

    def self.on_tariff_updates_applied(payload)
      ClearCacheWorker.perform_async
      ClearInvalidSearchReferences.perform_async
      TreeIntegrityCheckWorker.perform_async
      PopulateChangesTableWorker.perform_async

      if payload[:service] == 'xi'
        # NOTE: Delayed to allow materialized views to finish populating before
        #       green lanes category assessments are calculated.
        GreenLanesUpdatesWorker.perform_in(15.minutes, payload[:oldest_pending_date])
      end
    end

    def self.on_tariff_cache_cleared(payload)
      PopulateTariffChangesWorker.perform_async if payload[:service] == 'uk'
    end
  end
end
