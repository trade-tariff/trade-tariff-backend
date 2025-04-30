module PublicUsers
  class Subscription < Sequel::Model(Sequel[:user_subscriptions].qualify(:public))
    plugin :auto_validations
    plugin :timestamps, update_on_create: true

    many_to_one :user, class: 'PublicUsers::User'
    many_to_one :subscription_type, class: 'Subscriptions::Type'

    def deactivate!
      update(active: false)
    end
  end
end
