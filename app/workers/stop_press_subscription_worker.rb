class StopPressSubscriptionWorker
  include Sidekiq::Worker

  # Orchestrator only enqueues children; keep retries low to limit duplicate fan-out.
  sidekiq_options retry: 3

  def perform(stop_press_id)
    @stop_press = News::Item.find(id: stop_press_id)
    queue
  end

  def queue
    users.each do |user|
      StopPressEmailWorker.perform_async(@stop_press.id, user.id)
    end
  end

private

  def users
    chapters = @stop_press.chapters.split(',').map(&:strip)

    PublicUsers::User
      .active
      .with_active_stop_press_subscription
      .matching_chapters(chapters)
  end
end
