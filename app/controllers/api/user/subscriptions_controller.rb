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

      def create_batch
        batcher.new.call(subscription_params[:targets], @current_user)
        @subscription.refresh
        render json: serialize(@subscription), status: :ok
      rescue ArgumentError => e
        render json: serialize_errors({ error: e.message }), status: :bad_request
      end

    private

      def serialize(subscription)
        Api::User::SubscriptionSerializer.new(subscription, include: [:subscription_type]).serializable_hash
      end

      def authenticate_token!
        if token.present?
          @subscription = PublicUsers::Subscription.find(uuid: token)
          @current_user = @subscription&.user
        end

        if Rails.env.development? && @current_user.nil?
          @current_user = PublicUsers::User.active[external_id: 'dummy_user']
          @current_user ||= PublicUsers::User.create(external_id: 'dummy_user')
          @current_user.email = 'dummy@user.com'
          @subscription ||= PublicUsers::Subscription.find(user_id: @current_user.id)
          if @subscription.nil?
            @subscription = PublicUsers::Subscription.create(user_id: @current_user.id)
          end
        end

        if @subscription.nil?
          render json: { message: 'No token was provided' }, status: :unauthorized
        end
      end

      def token
        params[:id]
      end

      def subscription_params
        params.require(:data).require(:attributes).permit(
          :subscription_type,
          targets: [],
        )
      end

      def serialize_errors(errors)
        Api::User::ErrorSerializationService.new.serialized_errors(errors)
      end

      def subscription_type
        @subscription_type ||= Subscriptions::Type.find(name: subscription_params[:subscription_type])
      end

      def batcher
        "BatcherService::#{subscription_type.name.camelize}BatcherService".constantize
      rescue NameError
        raise ArgumentError, "Unsupported subscription type for batching: #{subscription_params[:subscription_type]}"
      end
    end
  end
end
