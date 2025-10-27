module PublicUsers
  class SubscriptionTarget < Sequel::Model(Sequel[:user_subscription_targets].qualify(:public))
    plugin :auto_validations
    plugin :timestamps, update_on_create: true

    many_to_one :subscription, class: 'PublicUsers::Subscription', key: :user_subscriptions_uuid, primary_key: :uuid

    dataset_module do
      def commodities
        where(target_type: 'commodity')
      end
    end

    def self.add_targets_for_subscription(subscription:, targets:, target_type:)
      raise ArgumentError, 'subscription must be present' unless subscription
      return if targets.blank?

      now = Time.zone.now
      dataset = self.dataset

      PublicUsers::SubscriptionTarget.db.transaction do
        dataset.where(
          user_subscriptions_uuid: subscription.uuid,
          target_type: target_type,
        ).delete

        rows = targets.map do |target|
          {
            user_subscriptions_uuid: subscription.uuid,
            target_id: target[:goods_nomenclature_sid],
            target_type: target_type,
            created_at: now,
            updated_at: now,
          }
        end

        dataset.multi_insert(rows)
      end
    end
  end
end
