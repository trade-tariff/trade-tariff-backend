module PublicUsers
  class User < Sequel::Model(Sequel[:users].qualify(:public))
    plugin :auto_validations
    plugin :timestamps, update_on_create: true

    one_to_one :preferences, class: 'PublicUsers::Preferences', key: :user_id
    one_to_many :subscriptions, class: 'PublicUsers::Subscription', key: :user_id
    one_to_many :action_logs, class: 'PublicUsers::ActionLog', key: :user_id
    one_to_many :delta_preferences, class: 'PublicUsers::DeltaPreferences', key: :user_id

    delegate :chapter_ids, to: :preferences

    def active_commodity_codes
      @active_commodity_codes ||= commodity_codes_grouped[:active]
    end

    def expired_commodity_codes
      @expired_commodity_codes ||= commodity_codes_grouped[:expired]
    end

    def erroneous_commodity_codes
      @erroneous_commodity_codes ||= commodity_codes_grouped[:erroneous]
    end

    def commodity_codes_grouped
      codes = delta_preferences.map(&:commodity_code)

      return { active: [], expired: [], erroneous: [] } if codes.empty?

      gns = GoodsNomenclature.where(goods_nomenclature_item_id: codes).all
      gns_by_code = gns.index_by(&:goods_nomenclature_item_id)

      active = []
      expired = []
      erroneous = []

      codes.each do |code|
        gn = gns_by_code[code]
        if gn.nil?
          erroneous << code
        elsif goods_nomenclature_active?(gn)
          active << code
        else
          expired << code
        end
      end

      { active:, expired:, erroneous: }
    end

    def commodity_codes=(codes)
      codes = Array(codes).reject(&:blank?).uniq

      PublicUsers::User.db.transaction do
        delta_preferences_dataset.delete

        unless codes.empty?
          values = codes.map do |code|
            {
              user_id: id,
              commodity_code: code,
              created_at: Time.zone.now,
              updated_at: Time.zone.now,
            }
          end
          PublicUsers::DeltaPreferences.multi_insert(values)
        end
      end
    end

    attr_writer :email

    dataset_module do
      def active
        where(deleted: false)
      end

      def with_active_stop_press_subscription
        with_active_subscription(Subscriptions::Type.stop_press)
      end

      def with_active_subscription(type)
        join(:public__user_subscriptions, Sequel[:user_subscriptions][:user_id] => Sequel[:users][:id])
          .where(
            Sequel[:user_subscriptions][:active] => true,
            Sequel[:user_subscriptions][:subscription_type_id] => type.id,
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

      def matching_commodity_codes(commodity_codes)
        return self if commodity_codes.blank?

        commodity_code_conditions = Array(commodity_codes).map { |commodity_code|
          Sequel.like(:user_delta_preferences__commodity_code, commodity_code)
        }.inject(:|)

        all_conditions = commodity_code_conditions | Sequel.expr(user_delta_preferences__commodity_code: nil) | Sequel.like(:user_delta_preferences__commodity_code, '')

        join(:public__user_delta_preferences, Sequel[:user_delta_preferences][:user_id] => Sequel[:users][:id])
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
      subscription_for(Subscriptions::Type.stop_press)
    end

    def subscription_for(type)
      subscriptions_dataset.where(subscription_type: type, active: true).first&.uuid || false
    end

    def stop_press_subscription=(active)
      set_subscription(Subscriptions::Type.stop_press, active)
    end

    def set_subscription(type, active)
      current = subscriptions_dataset.where(subscription_type: type).first

      if current
        current.update(active:)
      else
        add_subscription(subscription_type: type, active:)
        PublicUsers::ActionLog.create(user_id: id, action: PublicUsers::ActionLog::SUBSCRIBED) if active
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

    def goods_nomenclature_active?(gn_code)
      gn_code.validity_start_date <= Time.zone.now &&
        (gn_code.validity_end_date.nil? || gn_code.validity_end_date >= Time.zone.now)
    end
  end
end
