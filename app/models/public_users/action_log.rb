module PublicUsers
  class ActionLog < Sequel::Model(Sequel[:user_action_logs].qualify(:public))
    REGISTERED = 'registered'.freeze
    SUBSCRIBED_STOP_PRESS = 'subscribed stop_press'.freeze
    SUBSCRIBED_MY_COMMODITIES = 'subscribed my_commodities'.freeze
    UNSUBSCRIBED_STOP_PRESS = 'unsubscribed stop_press'.freeze
    UNSUBSCRIBED_MY_COMMODITIES = 'unsubscribed my_commodities'.freeze
    DELETED = 'deleted'.freeze
    FAILED_SUBSCRIBER = 'failed subscriber'.freeze

    ALLOWED_ACTIONS = [REGISTERED, SUBSCRIBED_STOP_PRESS, SUBSCRIBED_MY_COMMODITIES, UNSUBSCRIBED_STOP_PRESS, UNSUBSCRIBED_MY_COMMODITIES, DELETED, FAILED_SUBSCRIBER].freeze

    plugin :auto_validations
    plugin :timestamps, update_on_create: true

    many_to_one :user, class: 'PublicUsers::User'

    def validate
      super
      errors.add(:action, 'is not valid') unless ALLOWED_ACTIONS.include?(action)
    end
  end
end
