require_relative '../helpers/materialize_view_helper'
class RollbackWorker
  include Sidekiq::Worker
  include MaterializeViewHelper

  sidekiq_options queue: :sync, retry: false

  def perform(date, redownload = false)
    if TradeTariffBackend.uk?
      CdsSynchronizer.rollback(date, keep: redownload)
    else
      TaricSynchronizer.rollback(date, keep: redownload)
    end

    refresh_materialized_view
  end
end
