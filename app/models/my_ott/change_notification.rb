module MyOtt
  class ChangeNotification < Sequel::Model(Sequel[:change_notifications].qualify(:public))
    plugin :auto_validations
    plugin :timestamps, update_on_create: true

    many_to_one :user_subscriptions, class: 'PublicUsers::Subscription', key: :user_id
  end
end
