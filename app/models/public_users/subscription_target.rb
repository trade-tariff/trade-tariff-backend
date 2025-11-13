module PublicUsers
  class SubscriptionTarget < Sequel::Model(Sequel[:user_subscription_targets].qualify(:public))
    plugin :auto_validations
    plugin :timestamps, update_on_create: true

    attr_accessor :commodity, :virtual_id # for representing NullCommodities

    many_to_one :subscription, class: 'PublicUsers::Subscription', key: :user_subscriptions_uuid, primary_key: :uuid

    def id
      super || virtual_id
    end

    dataset_module do
      def commodities
        where(target_type: 'commodity')
      end
    end
  end
end
