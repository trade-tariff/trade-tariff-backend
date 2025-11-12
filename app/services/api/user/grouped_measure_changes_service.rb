module Api
  module User
    class GroupedMeasureChangesService
      attr_reader :user, :id, :date

      def initialize(user, id = nil, date = Time.zone.yesterday)
        @user = user
        @id = id
        @date = date
      end

      def call
        if id.present?
          measures
        else
          measures_grouped
        end
      end

      private

      def measures
        grouped_measure_change = TariffChanges::GroupedMeasureChange.from_id(id)

        measure_sids = changed_measures
          .join(:measure_types, measure_type_id: :measure_type_id)
          .where(Sequel[:measure_types][:trade_movement_code] => grouped_measure_change.trade_direction_code)
          .where(Sequel[:measures][:geographical_area_id] => grouped_measure_change.geographical_area_id)
          .select(:measure_sid)

        TariffChange.measures
                    .where(operation_date: date)
                    .where(object_sid: measure_sids)
                    .group(:goods_nomenclature_item_id)
                    .order(:goods_nomenclature_item_id)
                    .select(
                      :goods_nomenclature_item_id,
                      Sequel.lit('COUNT(*)').as(:count),
                    ).map do |row|
                      grouped_measure_change.add_commodity_change(
                        goods_nomenclature_item_id: row.values[:goods_nomenclature_item_id],
                        count: row.values[:count],
                      )
                    end

        grouped_measure_change
      end

      # Group changed measures by trade direction, geographical area and excluded area
      # Then load into TariffChanges::GroupedMeasureChange objects
      def measures_grouped
        changed_measures
          .join(:measure_types, measure_type_id: :measure_type_id)
          .left_join(
            :measure_excluded_geographical_areas,
            Sequel[:measure_excluded_geographical_areas][:measure_sid] => Sequel[:measures][:measure_sid],
          )
          .group(
            Sequel[:measure_types][:trade_movement_code],
            Sequel[:measures][:geographical_area_id],
          )
          .select(
            Sequel[:measure_types][:trade_movement_code],
            Sequel[:measures][:geographical_area_id],
            Sequel.function(:array_remove,
                            Sequel.function(:array_agg,
                                            Sequel.function(:distinct, Sequel[:measure_excluded_geographical_areas][:excluded_geographical_area])),
                            nil).as(:excluded_geographical_area_ids),
            Sequel.lit('COUNT(*)').as(:count),
          )
          .map do |row|
            TariffChanges::GroupedMeasureChange.new(
              trade_direction: MeasureType::TRADE_DIRECTION[row.values[:trade_movement_code]],
              count: row.values[:count],
              geographical_area_id: row.values[:geographical_area_id],
              excluded_geographical_area_ids: row.values[:excluded_geographical_area_ids] || [],
            )
          end
      end

      def changed_measures
        user_commodity_code_sids = @user.target_ids_for_my_commodities
        return Measure.where(false) if user_commodity_code_sids.blank?

        tariff_change_measure_sids = TariffChange.measures
                                                .where(operation_date: @date)
                                                .where(goods_nomenclature_sid: user_commodity_code_sids)
                                                .select(:object_sid)

        Measure.where(Sequel[:measures][:measure_sid] => tariff_change_measure_sids)
               .eager(:geographical_area, :measure_type)
      end

      def user_commodity_codes
        @user_commodity_codes ||= user.commodity_codes
      end
    end
  end
end
