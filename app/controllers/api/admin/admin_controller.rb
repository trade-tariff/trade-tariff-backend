module Api
  module Admin
    class AdminController < ApiController
      include GDS::SSO::ControllerMethods
      include AdminApi.routes.url_helpers

      def authenticate_user!
        TradeTariffBackend.disable_admin_api_authentication? || super
      end

      no_caching
    end
  end
end
