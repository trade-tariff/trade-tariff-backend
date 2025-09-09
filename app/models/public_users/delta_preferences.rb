module PublicUsers
  class DeltaPreferences < Sequel::Model(Sequel[:user_delta_preferences].qualify(:public))
    plugin :auto_validations
    plugin :timestamps, update_on_create: true
    plugin :validation_helpers

    many_to_one :user, class: 'PublicUsers::User', key: :user_id

    def validate
      super
      validates_presence [:commodity_code]
    end
  end
end
