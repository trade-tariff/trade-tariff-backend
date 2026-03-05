class RefreshActiveCommoditiesCacheWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    Api::User::ActiveCommoditiesService.refresh_caches

    active_codes = Api::User::ActiveCommoditiesService.all_active_commodities.map(&:second)
    expired_codes = Api::User::ActiveCommoditiesService.all_expired_commodities.map(&:second)

    TimeMachine.now do
      CachedCommodityDescriptionService.fetch_for_codes((active_codes + expired_codes).uniq)
    end

    nil
  end
end
