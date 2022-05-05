class ScheduledHealthcheckWorker
  include Sidekiq::Worker

  sidekiq_options queue: :healthcheck, retry: false

  def perform
    # Rather then trigger the health check immediately, this enqueues a second
    # job using the redis backed queue to verify async jobs are also working

    Sidekiq::Client.enqueue AsyncHealthcheckWorker
  end
end
