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
        TariffChanges::GroupedMeasureCommodityChange.from_id(grouped_measure_change_id)
      end
    end
  end
end
