class TaricSequenceCheckWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    return if TradeTariffBackend.uk?

    logger.info 'Running TARIC files sequence check'
    TariffSynchronizer::TaricSequenceChecker.new.perform
  end
end
