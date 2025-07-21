class PrewarmQuotaOrderNumbersWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: true

  def perform
    TimeMachine.now do
      CachedQuotaOrderNumberService.new.call
    end
  end
end
