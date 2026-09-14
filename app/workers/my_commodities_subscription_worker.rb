class MyCommoditiesSubscriptionWorker
  include Sidekiq::Worker

  # Orchestrator only enqueues children; keep retries low to limit duplicate fan-out.
  sidekiq_options retry: 3

  # Stamping only happens once the whole enqueue loop has run without raising. It records
  # "this date has been handed off", not "every email landed", which is all this worker can
  # observe. A date with nothing to send is genuinely done, so it is stamped too, otherwise
  # it would sit in the redrive set forever. Delivery failures are reported back by
  # MyCommoditiesEmailWorker's sidekiq_retries_exhausted hook, which returns the date to
  # TariffChangesJobStatus.pending_emails.
  def perform(date = Time.zone.yesterday.iso8601)
    @date = Date.parse(date)
    queue
    TariffChangesJobStatus.for_date(@date).mark_emails_sent!
  end

  def queue
    users_with_changes.each do |user_id, changes_count|
      MyCommoditiesEmailWorker.perform_async(user_id, @date.strftime(MyCommoditiesEmailWorker::DATE_FORMAT), changes_count)
    end
  end

private

  def users_with_changes
    PublicUsers::User
      .with_active_my_commodities_subscription
      .select_append { count(Sequel[:tariff_changes][:id]).as(:change_count) }
      .join(:user_subscription_targets, user_subscriptions_uuid: Sequel[:user_subscriptions][:uuid])
      .join(:tariff_changes,
            goods_nomenclature_sid: Sequel[:user_subscription_targets][:target_id],
            operation_date: @date)
      .group(Sequel[:users][:id])
      .map { |user| [user.id, user[:change_count]] }
  end
end
