module PublicUsers
  class User < Sequel::Model(Sequel[:users].qualify(:public))
    plugin :auto_validations
    plugin :timestamps, update_on_create: true

    one_to_many :subscriptions, class: 'PublicUsers::Subscription', key: :user_id

    attr_accessor :email
  end
end
