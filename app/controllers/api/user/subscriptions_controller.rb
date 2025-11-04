module Api
  module User
    class SubscriptionsController < ApiController
      include PublicUserAuthenticatable

      no_caching

      before_action :authenticate_user!, except: %i[destroy]
      before_action :find_subscription

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

      def find_subscription
        if subscription_id.present?
          @subscription = if @current_user.present?
                            @current_user.subscriptions_dataset.where(uuid: subscription_id).first
                          else
                            PublicUsers::Subscription.find(uuid: subscription_id)
                          end
        end

        if @subscription.nil?
          render json: { message: 'No subscription ID was provided' }, status: :unauthorized
        end
      end

      def subscription_id
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
