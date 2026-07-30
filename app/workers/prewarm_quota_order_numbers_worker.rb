class PrewarmQuotaOrderNumbersWorker
  include Sidekiq::Worker

  # Cap retries: retry: true uses Sidekiq's default (~25).
  sidekiq_options queue: :sync, retry: 3

  def perform
    TimeMachine.now do
      CachedQuotaOrderNumberService.new.call
    end
  end
end
