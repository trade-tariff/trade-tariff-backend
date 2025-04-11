module Api
  module Admin
    class AdminController < ApiController
      include GDS::SSO::ControllerMethods

      def authenticate_user!
        TradeTariffBackend.disable_admin_api_authentication? || super
      end
    end
  end
end
