module Api
  module User
    class DummyUserService
      DUMMY_USER_EXTERNAL_ID = 'dummy_user'.freeze
      DUMMY_USER_EMAIL = 'dummy@user.com'.freeze

      class << self
        def find_or_create
          return unless Rails.env.development?

          dummy_user = PublicUsers::User.active[external_id: DUMMY_USER_EXTERNAL_ID]
          dummy_user ||= PublicUsers::User.create(external_id: DUMMY_USER_EXTERNAL_ID)
          dummy_user.email = DUMMY_USER_EMAIL
          dummy_user
        end
      end
    end
  end
end
