module Api
  module User
    class SubscriptionTargetsController < ApiController
      no_caching

      def index
        # TODO: only allow user's subscriptions
        @subscription = PublicUsers::Subscription.find(uuid: params[:subscription_id])

        if @subscription.nil?
          render json: { message: 'No token was provided' }, status: :unauthorized
          return
        end

        render json: serialize(targets)
      end

      private

      def targets
        filter_params = subscription_params[:filter] || {}

        if filter_params[:active_commodities_type].present?
          TimeMachine.now do
            codes = Api::User::ActiveCommoditiesService.new(@subscription).call[filter_params[:active_commodities_type]]
            @subscription.subscription_targets.select do |sub_target|
              obj = sub_target.target
              obj && target.respond_to?(:goods_nomenclature_item_id) && codes.include?(obj.goods_nomenclature_item_id)
            end
          end
        else
          @subscription.subscription_targets
        end
      end

      def subscription_params
        params.require(:data).require(:attributes).permit(
          filter: {},
        )
      end

      def serialize(targets)
        Api::User::SubscriptionTargetSerializer.new(targets).serializable_hash
      end
    end
  end
end
