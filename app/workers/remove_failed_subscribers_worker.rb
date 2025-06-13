class RemoveFailedSubscribersWorker
  include Sidekiq::Worker

  def perform
    PublicUsers::User.failed_subscribers.each(&:soft_delete!)
  end
end
