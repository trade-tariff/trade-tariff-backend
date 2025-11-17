module Api
  module User
    class GroupedMeasureCommodityChangesService
      attr_reader :grouped_measure_change_id, :id, :date

      def initialize(grouped_measure_change_id, id, date = Time.zone.yesterday)
        @grouped_measure_change_id = grouped_measure_change_id
        @id = id
        @date = date
      end

      def call
        commodity_change = TariffChanges::GroupedMeasureCommodityChange.from_id(grouped_measure_change_id)

        if commodity_change.goods_nomenclature_item_id
          commodity = GoodsNomenclature.find(goods_nomenclature_item_id: commodity_change.goods_nomenclature_item_id)
          commodity_change.commodity = commodity
        end

        commodity_change
      end
    end
  end
end
