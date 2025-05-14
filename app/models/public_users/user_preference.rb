module PublicUsers
  class UserPreference < Sequel::Model(Sequel[:user_preferences].qualify(:public))
    plugin :auto_validations
    plugin :timestamps, update_on_create: true
  end
end
