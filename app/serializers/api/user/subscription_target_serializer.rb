module Api
  module User
    class SubscriptionTargetSerializer
      def initialize(subscription_targets, options = {})
        @subscription_targets = subscription_targets
        @options = options
      end

      def serializable_hash
        targets_array = @subscription_targets.map do |sub_target|
          "Api::User::SubscriptionTarget::#{sub_target.target_type.camelize}Serializer".constantize.new(sub_target.target).serializable_hash
        end

        {
          data: targets_array,
        }
      end
    end
  end
end
