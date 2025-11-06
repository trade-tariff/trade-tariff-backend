module Api
  module User
    class SubscriptionTargetsController < ApiController
      include PublicUserAuthenticatable

      no_caching

      before_action :authenticate!
      before_action :find_subscription

      def show
        if @subscription.nil?
          render json: { message: 'No token was provided' }, status: :unauthorized
          return
        end

        render json: serialize(targets)
      end

      private

      def targets
        if filter_params[:active_commodities_type].present?
          TimeMachine.now do
            codes = Api::User::ActiveCommoditiesService.new(@subscription).call[filter_params[:active_commodities_type].to_sym]
            return [] if codes.nil?

            @subscription.subscription_targets.select do |sub_target|
              obj = sub_target.target
              obj && obj.respond_to?(:goods_nomenclature_item_id) && codes.include?(obj.goods_nomenclature_item_id)
            end
          end
        else
          @subscription.subscription_targets
        end
      end

      def filter_params
        params.fetch(:filter, {}).permit(:active_commodities_type)
      end

      def serialize(targets)
        Api::User::SubscriptionTargetSerializer.new(targets).serializable_hash
      end

      def find_subscription
        @subscription = @current_user.subscriptions_dataset.where(uuid: subscription_id).first

        if @subscription.nil?
          render json: { message: 'No subscription ID was provided' }, status: :unauthorized
        end
      end

      def subscription_id
        params[:id]
      end
    end
  end
end
