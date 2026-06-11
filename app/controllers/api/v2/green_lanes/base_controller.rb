module Api
  module V2
    module GreenLanes
      class BaseController < ApiController
        no_caching

        include ApiKeyAuthenticatable
        include ApiTokenAuthenticatable

        before_action :check_service, :authenticate, :set_request_scope

        protected

        def append_info_to_payload(payload)
          super
          payload[:client_id] = @client_id
          payload[:auth_type] = @auth_type
        end

        private

        def check_service
          if TradeTariffBackend.uk?
            raise ActionController::RoutingError, 'Invalid service'
          end
        end

        def set_request_scope
          TradeTariffRequest.green_lanes = true
        end

        def authenticate
          return if skip_authentication?

          authenticated = false
          authenticated ||= authenticate_with_api_keys
          authenticated ||= authenticate_with_api_tokens

          return if authenticated

          render json: { error: 'Invalid API Key' }, status: :bad_request
        end

        def skip_authentication?
          return false unless Rails.env.development?

          no_api_keys = api_keys.blank?
          no_api_tokens = TradeTariffBackend.api_tokens.blank?

          no_api_keys && no_api_tokens
        end
      end
    end
  end
end
