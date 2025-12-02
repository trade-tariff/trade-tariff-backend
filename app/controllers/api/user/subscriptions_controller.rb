module Api
  module User
    class SubscriptionsController < ApiController
      include PublicUserAuthenticatable

      no_caching

      before_action :authenticate!, except: %i[destroy]
      before_action :find_subscription

      def show
        render json: serialize(@subscription)
      end

      # subscriptions are deleted without a user being authenticated
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
          targets: [],
        )
      end

      def serialize_errors(errors)
        Api::User::ErrorSerializationService.new.serialized_errors(errors)
      end

      def batcher
        subscription_type_name = @subscription.subscription_type.name
        "Api::User::BatcherService::#{subscription_type_name.camelize}BatcherService".constantize
      rescue NameError
        raise ArgumentError, "Unsupported subscription type for batching: #{subscription_type_name}"
      end
    end
  end
end
