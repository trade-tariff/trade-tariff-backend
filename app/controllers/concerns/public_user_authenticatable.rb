module PublicUserAuthenticatable
  extend ActiveSupport::Concern

  AUTHENTICATION_ERROR_MESSAGES = {
    missing_token: 'No bearer token was provided',
    expired: 'Token has expired',
    invalid_token: 'Token is invalid or malformed',
    not_in_group: 'User is not authorized to access this service',
    missing_jwks_keys: 'Unable to verify token',
  }.freeze

private

  attr_reader :current_user

  def authenticate!
    if Rails.env.development?
      @current_user ||= Api::User::DummyUserService.find_or_create
      return
    end

    if user_token.present?
      authenticate_user_token
    else
      render_authentication_error(:missing_token)
    end
  end

  def authenticate_user_token
    result = Api::User::UserService.find(user_token)

    return render_authentication_error(result.reason) if result.is_a?(CognitoTokenVerifier::Result)
    return render_not_found_error if result.nil?

    @current_user = result
  end

  def render_authentication_error(reason)
    error_detail = AUTHENTICATION_ERROR_MESSAGES[reason] || 'Authentication failed'

    render json: serialize_authentication_error(error_detail, reason), status: :unauthorized
  end

  def render_not_found_error
    render json: serialize_authentication_error('User not found', :not_found), status: :not_found
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
