class MyCommoditiesSubscriptionWorker
  include Sidekiq::Worker

  def perform(date = Time.zone.yesterday.iso8601)
    @date = Date.parse(date)
    queue
  end

  def queue
    users_with_changes.each do |user_id, changes_count|
      MyCommoditiesEmailWorker.perform_async(user_id, @date.strftime('%d/%m/%Y'), changes_count)
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
