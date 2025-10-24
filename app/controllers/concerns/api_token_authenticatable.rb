module ApiTokenAuthenticatable
  extend ActiveSupport::Concern

  included do
    include ActionController::HttpAuthentication::Token::ControllerMethods

    def authenticate!
      return if Rails.env.development?

      unless authenticate_with_api_tokens
        render json: { error: 'Invalid API Token' }, status: :unauthorized
      end
    end

    def authenticate_with_api_tokens
      authenticate_or_request_with_http_token do |provided_token, _options|
        Rails.logger.debug "Provided token: #{provided_token}"

        api_tokens.any? { |token|
          ActiveSupport::SecurityUtils.secure_compare(provided_token, token)
        }.tap do |authenticated|
          @auth_type = 'authorisation' if authenticated
        end
      end

      true
    end

    private

    def api_tokens
      @api_tokens ||= read_tokens
    end

    def read_tokens
      tokens = TradeTariffBackend.api_tokens
      if tokens.present?
        tokens.split(',').map(&:strip)
      else
        []
      end
    end
  end
end
