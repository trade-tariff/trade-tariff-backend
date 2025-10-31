module Api
  module User
    class SubscriptionsController < ApiController
      no_caching

      before_action :set_subscription_type, :authenticate_token!

      def index
        meta = meta_for(@type)
        render json: serialize(@subscription, meta: meta, include: [:subscription_type])
      end

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

      def set_subscription_type
        @type =
          case action_name
          when 'index'
            raise ArgumentError, 'please provide filter[subscription_type]' if filter_params[:subscription_type].blank?

            Subscriptions::Type.find(name: filter_params[:subscription_type])
          when 'create_batch'
            raise ArgumentError, 'please provide data[attributes][subscription_type]' if subscription_params[:subscription_type].blank?

            Subscriptions::Type.find(name: subscription_params[:subscription_type])
          when 'show', 'destroy'
            Subscriptions::Type.stop_press
          else
            raise ArgumentError, 'unknown action'
          end

        raise ArgumentError, 'subscription type not found' if @type.blank?
      rescue ArgumentError => e
        render json: serialize_errors({ error: e.message }), status: :bad_request
      end

      def serialize(subscription, meta: nil, include: nil)
        options = {}
        options[:include] = include if include
        options[:params] = { meta: meta } if meta

        Api::User::SubscriptionSerializer.new(subscription, options).serializable_hash
      end

      def authenticate_token!
        if token.present?
          @subscription = PublicUsers::Subscription.find(uuid: token, subscription_type_id: @type.id)
          @current_user = @subscription&.user
        end

        if Rails.env.development? && @current_user.nil?
          @current_user = PublicUsers::User.active[external_id: 'dummy_user']
          @current_user ||= PublicUsers::User.create(external_id: 'dummy_user')
          @current_user.email = 'dummy@user.com'
          @subscription ||= PublicUsers::Subscription.find(user_id: @current_user.id, subscription_type_id: @type.id)
          if @subscription.nil?
            @subscription = PublicUsers::Subscription.create(user_id: @current_user.id, subscription_type_id: @type.id)
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

      def filter_params
        params.fetch(:filter, {}).permit(:subscription_type)
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

      def meta_for(subscription_type)
        if subscription_type.name == Subscriptions::Type::MY_COMMODITIES
          targets = @subscription.subscription_targets_dataset.commodities.map(&:target_id)
          Api::User::ActiveCommoditiesService
            .new(@subscription.metadata['commodity_codes'], targets)
            .call
        end
      end
    end
  end
end
