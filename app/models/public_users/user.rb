module PublicUsers
  class User < Sequel::Model(Sequel[:users].qualify(:public))
    plugin :auto_validations
    plugin :timestamps, update_on_create: true

    one_to_one :preferences, class: 'PublicUsers::Preferences', key: :user_id
    one_to_many :subscriptions, class: 'PublicUsers::Subscription', key: :user_id
    one_to_many :action_logs, class: 'PublicUsers::UserActionLog', key: :user_id

    delegate :chapter_ids, to: :preferences

    attr_writer :email

    dataset_module do
      def with_active_stop_press_subscription
        join(:public__user_subscriptions, user_id: :id)
          .where(
            Sequel[:user_subscriptions][:active] => true,
            Sequel[:user_subscriptions][:subscription_type_id] => Subscriptions::Type.stop_press.id,
          )
          .select_all(:users)
          .distinct
      end

      def matching_chapters(chapters)
        return self if chapters.blank?

        chapter_conditions = Array(chapters).map { |chapter|
          Sequel.like(:user_preferences__chapter_ids, "%#{chapter}%")
        }.inject(:|)

        all_conditions = chapter_conditions | Sequel.expr(user_preferences__chapter_ids: nil) | Sequel.like(:user_preferences__chapter_ids, '')

        join(:public__user_preferences, user_id: :id)
          .where(all_conditions)
          .select_all(:users)
      end
    end

    def email
      @email ||= IdentityApiClient.get_email(external_id)
    end

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
