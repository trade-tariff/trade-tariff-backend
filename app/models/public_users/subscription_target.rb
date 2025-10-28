module PublicUsers
  class SubscriptionTarget < Sequel::Model(Sequel[:user_subscription_targets].qualify(:public))
    plugin :auto_validations
    plugin :timestamps, update_on_create: true

    many_to_many :subscription, class: 'PublicUsers::Subscription'
    many_to_many :subscription_type, class: 'Subscriptions::Type'
  end
end
