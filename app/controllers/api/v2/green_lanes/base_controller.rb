module Api
  module V2
    module GreenLanes
      class BaseController < ApiController
        include ActionController::HttpAuthentication::Token::ControllerMethods

        before_action :check_service, :authenticate, :set_request_scope

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
          unless Rails.env.development? && TradeTariffBackend.green_lanes_api_keys.blank?
            authenticated = authenticate_with_api_keys
          end

          unless Rails.env.development? && TradeTariffBackend.green_lanes_api_tokens.blank?
            authenticated ||= authenticate_with_api_tokens
          end

          unless authenticated || (Rails.env.development? && TradeTariffBackend.green_lanes_api_keys.blank?)
            render json: { error: 'Invalid API Key' }, status: :bad_request
          end
        end

        def authenticate_with_api_tokens
          authenticate_or_request_with_http_token do |provided_token, _options|
            Rails.logger.debug "Provided token: #{provided_token}"
            api_tokens.any? { |token| ActiveSupport::SecurityUtils.secure_compare(provided_token, token) }
          end

          true
        end

        def authenticate_with_api_keys
          provided_key = request.headers['X-Api-Key']
          return false if provided_key.blank?

          Rails.logger.debug "Provided key: #{provided_key}"

          return false unless api_keys.any? { |api_key| ActiveSupport::SecurityUtils.secure_compare(provided_key, api_key) }

          true
        end

        def api_tokens
          @api_tokens ||= read_tokens
        end

        def api_keys
          @api_keys ||= read_api_keys
        end

        def read_api_keys
          api_key_hash = JSON.parse(TradeTariffBackend.green_lanes_api_keys)
          if api_key_hash.any?
            api_key_hash['api_keys'].keys
          else
            []
          end
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
