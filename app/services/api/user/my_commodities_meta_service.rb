module Api
  module User
    class MyCommoditiesMetaService
      def initialize(commodity_codes, subscription_target_ids)
        @commodity_codes = commodity_codes
        @subscription_target_ids = subscription_target_ids
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
