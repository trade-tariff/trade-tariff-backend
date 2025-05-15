module Api
  module User
    class UserController < ApiController
      before_action :authenticate_token!

      attr_reader :current_user

    private

      def authenticate_token!
        if token.present?
          payload = CognitoTokenVerifier.verify_id_token(token)
          if payload
            @current_user = PublicUsers::User.find(external_id: payload['sub'])
            @current_user ||= PublicUsers::User.create(external_id: payload['sub'])
          end
        end

        if @current_user.nil?
          render json: { message: 'No bearer token was provided' }, status: :unauthorized
        end
      end

      def token
        pattern = /^Bearer /
        header = request.headers['Authorization']
        header.gsub(pattern, '') if header&.match(pattern)
      end
    end
  end
end
