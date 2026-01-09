module PublicUserAuthenticatable
  extend ActiveSupport::Concern

  AUTHENTICATION_ERROR_MESSAGES = {
    missing_token: 'No bearer token was provided',
    expired: 'Token has expired',
    invalid_token: 'Token is invalid or malformed',
    not_in_group: 'User is not authorized to access this service',
    missing_jwks_keys: 'Unable to verify token',
  }.freeze

  included do
    private

    def authenticate!
      if user_token.present?
        result = Api::User::UserService.find_or_create(user_token)

        if result.is_a?(CognitoTokenVerifier::Result)
          return render_authentication_error(result.reason)
        end

        @current_user = result
      end

      if Rails.env.development?
        @current_user ||= Api::User::DummyUserService.find_or_create
      end

      if @current_user.nil?
        render_authentication_error(:missing_token)
      end
    end

    def render_authentication_error(reason)
      error_detail = AUTHENTICATION_ERROR_MESSAGES[reason] || 'Authentication failed'

      render json: serialize_authentication_error(error_detail, reason), status: :unauthorized
    end

    def serialize_authentication_error(detail, reason)
      {
        errors: [{
          detail:,
          code: reason.to_s,
        }],
      }.to_json
    end

    def user_token
      pattern = /^Bearer /
      header = request.headers['Authorization']
      header.gsub(pattern, '') if header&.match(pattern)
    end
  end
end
