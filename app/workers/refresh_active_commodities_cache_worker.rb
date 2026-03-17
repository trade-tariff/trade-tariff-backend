class RefreshActiveCommoditiesCacheWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    Api::User::ActiveCommoditiesService.refresh_caches

    active_codes = Api::User::ActiveCommoditiesService.all_active_commodities.map(&:second)
    expired_codes = Api::User::ActiveCommoditiesService.all_expired_commodities.map(&:second)
    codes = (active_codes + expired_codes).uniq

    TimeMachine.now do
      Rails.logger.info "Caching #{codes.size} commodity code descriptions"
      CachedCommodityDescriptionService.cache_for_codes(codes)
      Rails.logger.info 'Caching commodity code descriptions completed'
    end

    nil
  end
end
