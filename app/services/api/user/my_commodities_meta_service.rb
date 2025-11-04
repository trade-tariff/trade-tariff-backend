module Api
  module User
    class MyCommoditiesMetaService
      def initialize(subscription)
        @commodity_codes = subscription.metadata['commodity_codes']
        @subscription_target_ids = subscription.subscription_targets_dataset.commodities.map(&:target_id)
      end

      def call
        TimeMachine.now do
          Api::User::ActiveCommoditiesService
            .new(commodity_codes, subscription_target_ids)
            .call
        end
      end

      private

      attr_reader :commodity_codes, :subscription_target_ids
    end
  end
end
