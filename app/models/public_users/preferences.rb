module PublicUsers
  class Preferences < Sequel::Model(Sequel[:user_preferences].qualify(:public))
    plugin :auto_validations
    plugin :timestamps, update_on_create: true
    plugin :validation_helpers

    many_to_one :user, class: 'PublicUsers::User', key: :user_id

    def validate
      super
      validates_format %r{\A[0-9]{2}(,[0-9]{2})*\z}, :chapter_ids, allow_blank: true
    end
  end
end
