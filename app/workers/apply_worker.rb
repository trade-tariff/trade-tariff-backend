require_relative '../helpers/materialize_view_helper'
class ApplyWorker
  include Sidekiq::Worker
  include MaterializeViewHelper

  sidekiq_options queue: :sync, retry: false

  def perform
    if TradeTariffBackend.uk?
      CdsSynchronizer.apply
    else
      TaricSynchronizer.apply
    end

    refresh_materialized_view

    # Clear frontend cache
    Rails.logger.info 'Clearing frontend cache'
    TradeTariffBackend.frontend_redis.flushdb
    Rails.logger.info 'Frontend cache cleared'

    # Queue a Sidekiq job to clear all caches
    ClearCacheWorker.perform_async
  end
end
