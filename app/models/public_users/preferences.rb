module PublicUsers
  class Preferences < Sequel::Model(Sequel[:user_preferences].qualify(:public))
    plugin :auto_validations
    plugin :timestamps, update_on_create: true

    many_to_one :user, class: 'PublicUsers::User', key: :user_id
  end
end
