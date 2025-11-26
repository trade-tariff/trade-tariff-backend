module Api
  module User
    class CommodityChangesService
      attr_reader :user, :id, :date

      ALLOWED_IDS = %w[ending classification].freeze

      def initialize(user, id = nil, date = Time.zone.yesterday)
        @user = user
        @id = id
        @date = date
      end

      def call
        if id.present? && ALLOWED_IDS.include?(id)
          send(id, with_records: true)
        else
          all_changes
        end
      end

      private

      def all_changes
        [
          ending,
          classification,
        ].compact
      end

      def ending(with_records: false)
        changes = TariffChange.commodities
                              .where(operation_date: date)
                              .where(goods_nomenclature_sid: user_commodity_code_sids)
                              .where(action: TariffChangesService::BaseChanges::ENDING)

        count = changes.count

        return if count.zero?

        TariffChanges::GroupedCommodityChange.new({
          id: 'ending',
          description: 'Changes to end date',
          count: count,
          tariff_changes: with_records ? changes.all : nil,
        })
      end

      def classification(with_records: false)
        changes = TariffChange.commodity_descriptions
                              .where(operation_date: date)
                              .where(goods_nomenclature_sid: user_commodity_code_sids)
                              .where(action: TariffChangesService::BaseChanges::UPDATE)
        count = changes.count

        return if count.zero?

        TariffChanges::GroupedCommodityChange.new({
          id: 'classification',
          description: 'Changes to classification',
          count: count,
          tariff_changes: with_records ? changes.all : nil,
        })
      end

      def user_commodity_code_sids
        @user_commodity_code_sids ||= @user.target_ids_for_my_commodities
      end
    end
  end
end
