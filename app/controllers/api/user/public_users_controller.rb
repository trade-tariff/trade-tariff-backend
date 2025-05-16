module Api
  module User
    class PublicUsersController < ApiController
      before_action :authenticate_token!

      attr_reader :current_user

      def show
        render json: serialize(@current_user)
      end

      def update
        @current_user.update(user_params)
        render json: serialize(@current_user)
      rescue Sequel::ValidationFailed
        render json: serialize_errors(@current_user.errors), status: :unprocessable_entity
      end

    private

      def user_params
        params.require(:data).require(:attributes).permit(
          :chapter_ids,
          :stop_press_subscription,
        )
      end

      def serialize(user)
        Api::User::PublicUserSerializer.new(user).serializable_hash
      end

      def serialize_errors(errors)
        Api::User::ErrorSerializationService.new.serialized_errors(errors)
      end

      def authenticate_token!
        if token.present?
          payload = CognitoTokenVerifier.verify_id_token(token)
          if payload
            @current_user = PublicUsers::User.find(external_id: payload['sub'])
            @current_user ||= PublicUsers::User.create(external_id: payload['sub'])
            @current_user.email = payload['email']
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
