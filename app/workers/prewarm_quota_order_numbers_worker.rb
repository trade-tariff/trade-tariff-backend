class PrewarmQuotaOrderNumbersWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: true

  def perform
    TimeMachine.now do
      CachedQuotaOrderNumberService.new.call
    end
  end
end
