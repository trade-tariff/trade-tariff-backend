module Api
  module User
    class UserController < ApiController
      include PublicUserAuthenticatable

      before_action :authenticate!

      no_caching

      private

      def actual_date
        super(Time.zone.yesterday)
      end
    end
  end
end
