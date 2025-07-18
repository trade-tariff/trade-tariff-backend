module PublicUsers
  class User < Sequel::Model(Sequel[:users].qualify(:public))
    plugin :auto_validations
    plugin :timestamps, update_on_create: true

    one_to_one :preferences, class: 'PublicUsers::Preferences', key: :user_id
    one_to_many :subscriptions, class: 'PublicUsers::Subscription', key: :user_id
    one_to_many :action_logs, class: 'PublicUsers::ActionLog', key: :user_id

    delegate :chapter_ids, to: :preferences

    attr_writer :email

    dataset_module do
      def active
        where(deleted: false)
      end

      def with_active_stop_press_subscription
        join(:public__user_subscriptions, Sequel[:user_subscriptions][:user_id] => Sequel[:users][:id])
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

        join(:public__user_preferences, Sequel[:user_preferences][:user_id] => Sequel[:users][:id])
          .where(all_conditions)
          .select_all(:users)
          .distinct
      end

      def failed_subscribers
        active
          .exclude(Sequel[:users][:id] => PublicUsers::Subscription.select(:user_id))
          .where { created_at < 72.hours.ago }
      end
    end

    def email
      @email ||= IdentityApiClient.get_email(external_id)
    end

    def stop_press_subscription
      subscriptions_dataset.where(subscription_type: Subscriptions::Type.stop_press, active: true).first&.uuid || false
    end

    def stop_press_subscription=(active)
      current = subscriptions_dataset.where(subscription_type: Subscriptions::Type.stop_press).first

      if current
        current.update(active:)
      else
        add_subscription(subscription_type: Subscriptions::Type.stop_press, active:)
        if active
          PublicUsers::ActionLog.create(user_id: id, action: PublicUsers::ActionLog::SUBSCRIBED)
        end
      end
    end

    def soft_delete!
      return if deleted
      return if subscriptions_dataset.where(active: true).any?

      update(deleted: true)

      PublicUsers::ActionLog.create(user_id: id, action: PublicUsers::ActionLog::DELETED)

      ExternalUserDeletionWorker.perform_async(id)
    end

  private

    def after_create
      super
      PublicUsers::Preferences.create(user_id: id)
      PublicUsers::ActionLog.create(user_id: id, action: PublicUsers::ActionLog::REGISTERED)
    end
  end
end
