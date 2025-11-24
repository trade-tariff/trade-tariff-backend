module Api
  module User
    class CommodityChangesService
      attr_reader :user, :date

      def initialize(user, date = Time.zone.yesterday)
        @user = user
        @date = date
      end

      def call
        [
          OpenStruct.new({
            id: 'commodity_endings',
            description: 'Changes to end date',
            count: count_commodity_endings,
          }),
          OpenStruct.new({
            id: 'classification_changes',
            description: 'Changes to classification',
            count: count_classification_changes,
          }),
        ]
      end

      private

      def count_commodity_endings
        TariffChange.commodities
                     .where(operation_date: date)
                     .where(goods_nomenclature_sid: user_commodity_code_sids)
                     .where(action: TariffChangesService::BaseChanges::ENDING)
                     .count
      end

      def count_classification_changes
        TariffChange.commodity_descriptions
                     .where(operation_date: date)
                     .where(goods_nomenclature_sid: user_commodity_code_sids)
                     .where(action: TariffChangesService::BaseChanges::UPDATE)
                     .count
      end

      def user_commodity_code_sids
        @user_commodity_code_sids ||= @user.target_ids_for_my_commodities
      end
    end
  end
end
