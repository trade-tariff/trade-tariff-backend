class RemoveFailedSubscribersWorker
  include Sidekiq::Worker

  # Soft-deletes are mostly idempotent; keep retries low vs Sidekiq default (25).
  sidekiq_options retry: 3

  def perform
    return unless TradeTariffBackend.uk?

    PublicUsers::User.failed_subscribers.each do |user|
      user.soft_delete!
      PublicUsers::ActionLog.create(user_id: user.id, action: PublicUsers::ActionLog::FAILED_SUBSCRIBER)
    end
  end
end
