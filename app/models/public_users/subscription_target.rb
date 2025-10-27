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
  end
end
