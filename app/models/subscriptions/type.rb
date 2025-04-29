module Subscriptions
  class Type < Sequel::Model(Sequel[:subscription_types].qualify(:public))
    plugin :auto_validations
    plugin :timestamps, update_on_create: true

    one_to_many :subscriptions, class: 'PublicUsers::Subscription', key: :subscription_type_id
  end
end
