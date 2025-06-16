module PublicUsers
  class ActionLog < Sequel::Model(Sequel[:user_action_logs].qualify(:public))
    REGISTERED = 'registered'.freeze
    SUBSCRIBED = 'subscribed'.freeze
    UNSUBSCRIBED = 'unsubscribed'.freeze
    DELETED = 'deleted'.freeze
    FAILED_SUBSCRIBER = 'failed subscriber'.freeze

    ALLOWED_ACTIONS = [REGISTERED, SUBSCRIBED, UNSUBSCRIBED, DELETED, FAILED_SUBSCRIBER].freeze

    plugin :auto_validations
    plugin :timestamps, update_on_create: true

    many_to_one :user, class: 'PublicUsers::User'

    def validate
      super
      errors.add(:action, 'is not valid') unless ALLOWED_ACTIONS.include?(action)
    end
  end
end
