module PublicUsers
  class ActionLog < Sequel::Model(Sequel[:user_action_logs].qualify(:public))
    plugin :auto_validations
    plugin :timestamps, update_on_create: true

    many_to_one :user, class: 'PublicUsers::User'
  end
end
