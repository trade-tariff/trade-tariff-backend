module Api
  module User
    class SubscriptionTargetsController < ApiController
      include PublicUserAuthenticatable
      include Pageable

      no_caching

      before_action :authenticate!
      before_action :find_subscription

      def index
        return render json: { message: 'No token was provided' }, status: :unauthorized if @subscription.nil?

        case @subscription.subscription_type.name
        when 'my_commodities'
          filter_service = "Api::User::TargetsFilterService::#{@subscription.subscription_type.name.camelize}TargetsFilterService".constantize
          filtered_targets = filter_service.new(@subscription,
                                                filter_params[:active_commodities_type]&.to_sym,
                                                current_page, per_page).call
        else
          raise ArgumentError, "Unsupported subscription type for targets filtering: #{@subscription.subscription_type.name}"
        end

        render json: serialize(filtered_targets)
      rescue ArgumentError => e
        render json: serialize_errors({ error: e.message }), status: :bad_request
      end

      private

      def filter_params
        params.fetch(:filter, {}).permit(:active_commodities_type)
      end

      def serialize(targets_and_total)
        targets, total = targets_and_total
        serialized_targets = Api::User::SubscriptionTargetSerializer.new(targets, include: [:target_object]).serializable_hash
        @total = total
        {
          data: serialized_targets[:data],
          included: serialized_targets[:included],
        }.merge(pagination_meta)
      end

      def record_count
        @total
      end

      def serialize_errors(errors)
        Api::User::ErrorSerializationService.new.serialized_errors(errors)
      end

      def find_subscription
        @subscription = @current_user.subscriptions_dataset.where(uuid: subscription_id).first
        render json: { message: 'No subscription ID was provided' }, status: :unauthorized if @subscription.nil?
      end

      def subscription_id
        params[:subscription_id]
      end
    end
  end
end
