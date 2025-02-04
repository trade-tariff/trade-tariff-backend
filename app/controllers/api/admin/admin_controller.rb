module Api
  module Admin
    class AdminController < ApiController
      include GDS::SSO::ControllerMethods

      def authenticate_user!
        if TradeTariffBackend.disable_admin_api_authentication?
          true
        else
          super
        end
      end

      no_caching
    end
  end
end
