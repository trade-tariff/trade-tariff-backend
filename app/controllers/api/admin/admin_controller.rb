module Api
  module Admin
    class AdminController < ApiController
      include GDS::SSO::ControllerMethods
      include AdminApi.routes.url_helpers
      include ActionController::HttpAuthentication::Token::ControllerMethods

      def authenticate_user!
        if TradeTariffBackend.disable_admin_api_authentication?
          if TradeTariffBackend.admin_api_bearer_token.blank?
            render json: { error: 'Admin API Key is not valid' }, status: :internal_server_error
            return
          end
          authenticate_with_bearer_token
        else
          super
        end
      end

      def authenticate_with_bearer_token
        authenticate_or_request_with_http_token do |provided_token, _options|
          ActiveSupport::SecurityUtils.secure_compare(provided_token, TradeTariffBackend.admin_api_bearer_token)
        end

        true
      end

      no_caching
    end
  end
end
