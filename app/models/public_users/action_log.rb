module PublicUsers
  class ActionLog < Sequel::Model(Sequel[:user_action_logs].qualify(:public))
    DELETED = 'deleted'.freeze
    FAILED_SUBSCRIBER = 'failed subscriber'.freeze
    INVALIDATED_MY_COMMODITIES = 'invalidated my_commodities'.freeze
    INVALIDATED_STOP_PRESS = 'invalidated stop_press'.freeze
    REGISTERED = 'registered'.freeze
    SUBSCRIBED_MY_COMMODITIES = 'subscribed my_commodities'.freeze
    SUBSCRIBED_STOP_PRESS = 'subscribed stop_press'.freeze
    UNSUBSCRIBED_MY_COMMODITIES = 'unsubscribed my_commodities'.freeze
    UNSUBSCRIBED_STOP_PRESS = 'unsubscribed stop_press'.freeze

    ALLOWED_ACTIONS = [
      DELETED,
      FAILED_SUBSCRIBER,
      INVALIDATED_MY_COMMODITIES,
      INVALIDATED_STOP_PRESS,
      REGISTERED,
      SUBSCRIBED_MY_COMMODITIES,
      SUBSCRIBED_STOP_PRESS,
      UNSUBSCRIBED_MY_COMMODITIES,
      UNSUBSCRIBED_STOP_PRESS,
    ].freeze

    plugin :auto_validations
    plugin :timestamps, update_on_create: true

    many_to_one :user, class: 'PublicUsers::User'

    def validate
      super
      errors.add(:action, 'is not valid') unless ALLOWED_ACTIONS.include?(action)
    end
  end
end
