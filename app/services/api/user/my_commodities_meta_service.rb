module Api
  module User
    class MyCommoditiesMetaService
      def initialize(subscription)
        @subscription = subscription
      end

      def call
        TimeMachine.now do
          Api::User::ActiveCommoditiesService
            .new(subscription)
            .call
        end
      end

      private

      attr_reader :subscription
    end
  end
end
