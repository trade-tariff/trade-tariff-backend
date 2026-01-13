class RefreshActiveCommoditiesCacheWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    Api::User::ActiveCommoditiesService.refresh_caches
  end
end
