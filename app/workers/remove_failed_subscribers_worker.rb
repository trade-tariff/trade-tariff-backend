class RemoveFailedSubscribersWorker
  include Sidekiq::Worker

  def perform
    return unless TradeTariffBackend.uk?

    PublicUsers::User.failed_subscribers.each do |user|
      user.soft_delete!
      PublicUsers::ActionLog.create(user_id: user.id, action: PublicUsers::ActionLog::FAILED_SUBSCRIBER)
    end
  end
end
