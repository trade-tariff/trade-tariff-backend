module Api
  module User
    class PublicUsersController < ApiController
      no_caching

      before_action :authenticate_user!

      attr_reader :current_user

      def show
        render json: serialize(@current_user)
      end

      def update
        if user_params[:chapter_ids]
          @current_user.preferences.update(chapter_ids: user_params[:chapter_ids])
        end

        if user_params[:stop_press_subscription]
          @current_user.stop_press_subscription = user_params[:stop_press_subscription]
        end

        if user_params[:my_commodities_subscription]
          @current_user.my_commodities_subscription = user_params[:my_commodities_subscription]
        end

        render json: serialize(@current_user)
      rescue Sequel::ValidationFailed => e
        render json: serialize_errors({ error: e }), status: :unprocessable_content
      end

    private

      def user_params
        params.require(:data).require(:attributes).permit(
          :chapter_ids,
          :stop_press_subscription,
          :my_commodities_subscription,
        )
      end

      def serialize(user)
        Api::User::PublicUserSerializer.new(user).serializable_hash
      end

      def serialize_errors(errors)
        Api::User::ErrorSerializationService.new.serialized_errors(errors)
      end

      def authenticate_user!
        if token.present?
          @current_user = Api::User::UserService.find_or_create(token)
        end

        if Rails.env.development?
          @current_user ||= Api::User::DummyUserService.find_or_create
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
