module Api
  module V2
    module GreenLanes
      class BaseController < ApiController
        include ActionController::HttpAuthentication::Token::ControllerMethods

        before_action :check_service, :authenticate

        private

        def check_service
          if TradeTariffBackend.uk?
            raise ActionController::RoutingError, 'Invalid service'
          end
        end

        def authenticate
          unless Rails.env.development? and TradeTariffBackend.green_lanes_api_tokens.blank?
            authenticate_or_request_with_http_token do |provided_token, _options|
              Rails.logger.debug provided_token
              api_tokens.any? { |token| ActiveSupport::SecurityUtils.secure_compare(provided_token, token) }
            end
          end
        end

        def api_tokens
          @api_tokens ||= read_tokens
        end

        def read_tokens
          tokens = TradeTariffBackend.green_lanes_api_tokens
          if tokens.present?
            tokens.split(',').map(&:strip)
          else
            []
          end
        end
      end
    end
  end
end
