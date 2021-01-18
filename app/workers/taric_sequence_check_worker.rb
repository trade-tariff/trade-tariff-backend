class TaricSequenceCheckWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    logger.info 'Running TARIC files sequence check'
    TariffSynchronizer::TaricSequenceChecker.new(true).perform
  end
end
