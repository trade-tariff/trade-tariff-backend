module PublicUsers
  class Subscription < Sequel::Model(Sequel[:user_subscriptions].qualify(:public))
    plugin :auto_validations
    plugin :timestamps, update_on_create: true

    many_to_one :user, class: 'PublicUsers::User'
    many_to_one :subscription_type, class: 'Subscriptions::Type'
    one_to_many :subscription_targets, class: 'PublicUsers::SubscriptionTarget', key: :user_subscriptions_uuid, primary_key: :uuid

    dataset_module do
      def with_my_commodities_subscription
        where(subscription_type: Subscriptions::Type.my_commodities)
      end
    end

    def unsubscribe
      if active
        update(active: false)
        PublicUsers::ActionLog.create(user_id: user.id, action: PublicUsers::ActionLog::UNSUBSCRIBED)
      end
      user.soft_delete!
    end

    def metadata
      value = self[:metadata]
      value.is_a?(String) ? JSON.parse(value) : value
    end

    def metadata=(value)
      self[:metadata] = value.is_a?(String) ? value : value.to_json
    end
  end
end
