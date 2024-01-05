module Api
  module V2
    module GreenLanes
      class BaseController < ApiController
        include ActionController::HttpAuthentication::Token::ControllerMethods

        before_action :authenticate

        private

        def authenticate
          authenticate_or_request_with_http_token do |provided_token, _options|
            api_tokens.any? { |token| ActiveSupport::SecurityUtils.secure_compare(provided_token, token) }
          end
        end

        def api_tokens
          @api_tokens ||= read_tokens
        end

        def read_tokens
          tokens = ENV['GREEN_LANES_API_TOKENS']
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
