module PublicUsers
  class User < Sequel::Model(Sequel[:users].qualify(:public))
    plugin :auto_validations
    plugin :timestamps, update_on_create: true

    one_to_one :preferences, class: 'PublicUsers::Preferences', key: :user_id
    one_to_many :subscriptions, class: 'PublicUsers::Subscription', key: :user_id

    delegate :chapter_ids, to: :preferences

    attr_accessor :email

    def stop_press_subscription
      subscriptions_dataset.where(subscription_type: Subscriptions::Type.stop_press, active: true).any?
    end

    def stop_press_subscription=(active)
      current = subscriptions_dataset.where(subscription_type: Subscriptions::Type.stop_press).first

      if current
        current.update(active:)
      else
        add_subscription(subscription_type: Subscriptions::Type.stop_press, active:)
      end
    end

  private

    def after_create
      super
      PublicUsers::Preferences.create(user_id: id)
    end
  end
end
