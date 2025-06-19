module Api
  module User
    class SubscriptionsController < ApiController
      no_caching

      before_action :authenticate_token!

      def show
        render json: serialize(@subscription)
      end

      def destroy
        @subscription.unsubscribe

        render json: { message: 'Unsubscribe successful' }, status: :ok
      end

    private

      def serialize(subscription)
        Api::User::SubscriptionSerializer.new(subscription).serializable_hash
      end

      def authenticate_token!
        if token.present?
          @subscription = PublicUsers::Subscription.find(uuid: token)
        end

        if @subscription.nil?
          render json: { message: 'No token was provided' }, status: :unauthorized
        end
      end

      def token
        params[:id]
      end
    end
  end
end
