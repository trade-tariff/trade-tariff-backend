module PublicUserAuthenticatable
  extend ActiveSupport::Concern

  included do
    private

    def authenticate!
      if user_token.present?
        @current_user = Api::User::UserService.find_or_create(user_token)
      end

      if Rails.env.development?
        @current_user ||= Api::User::DummyUserService.find_or_create
      end

      if @current_user.nil?
        render json: { message: 'No bearer token was provided' }, status: :unauthorized
      end
    end

    def user_token
      pattern = /^Bearer /
      header = request.headers['Authorization']
      header.gsub(pattern, '') if header&.match(pattern)
    end
  end
end
