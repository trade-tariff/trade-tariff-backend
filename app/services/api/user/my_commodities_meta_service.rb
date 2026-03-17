module Api
  module User
    class MyCommoditiesMetaService
      def initialize(subscription)
        @subscription = subscription
      end

      def call
        {
          counts:,
          published:,
        }
      end

      private

      attr_reader :subscription

      def counts
        TimeMachine.now do
          Api::User::ActiveCommoditiesService
            .new(subscription)
            .call
        end
      end

      def published
        yesterday_count = TariffChange
          .where(operation_date: Date.yesterday)
          .where(goods_nomenclature_sid: subscription.user.target_ids_for_my_commodities)
          .count

        {
          yesterday: yesterday_count,
          last_change_date: TariffChangesJobStatus.last_change_date,
        }
      end
    end
  end
end
