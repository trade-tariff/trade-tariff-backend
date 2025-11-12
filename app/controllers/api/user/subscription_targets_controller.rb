module Api
  module User
    class SubscriptionTargetsController < ApiController
      include PublicUserAuthenticatable

      no_caching

      before_action :authenticate!
      before_action :find_subscription

      def show
        return render json: { message: 'No token was provided' }, status: :unauthorized if @subscription.nil?

        render json: serialize(targets_with_commodities)
      end

      private

      def targets_with_commodities
        type = filter_params[:active_commodities_type]&.to_sym

        return [@subscription.subscription_targets.map, @subscription.subscription_targets.size] if type.blank?

        TimeMachine.now do
          service = Api::User::ActiveCommoditiesService.new(@subscription)
          commodities, total =
            if service.respond_to?("#{type}_commodities")
              service.public_send("#{type}_commodities", page: page, per_page: per_page)
            else
              [[], 0]
            end
          targets = apply_commodities_to_subscription_targets(commodities)
          [targets, total]
        end
      end

      def apply_commodities_to_subscription_targets(commodities)
        commodities.map do |commodity|
          subscription_target_id =
            find_target_id_by_goods_nomenclature_sid(commodity.goods_nomenclature_sid)

          target = PublicUsers::SubscriptionTarget.new
          target.virtual_id = subscription_target_id
          target.target_type = 'commodity'
          target.commodity = commodity
          target
        end
      end

      def find_target_id_by_goods_nomenclature_sid(sid)
        subscription_target = @subscription.subscription_targets_dataset.where(target_id: sid).first
        subscription_target&.id
      end

      def filter_params
        params.fetch(:filter, {}).permit(:active_commodities_type)
      end

      def page
        params[:page].presence&.to_i || 1
      end

      def per_page
        params[:per_page].presence&.to_i || 20
      end

      def serialize(targets_and_total)
        targets, total = targets_and_total

        serialized_targets = Api::User::SubscriptionTargetSerializer.new(targets).serializable_hash

        {
          data: serialized_targets[:data],
          meta: {
            pagination: {
              page: page,
              per_page: per_page,
              total_count: total,
            },
          },
        }
      end

      def find_subscription
        @subscription = @current_user.subscriptions_dataset.where(uuid: subscription_id).first
        render json: { message: 'No subscription ID was provided' }, status: :unauthorized if @subscription.nil?
      end

      def subscription_id
        params[:id]
      end
    end
  end
end
