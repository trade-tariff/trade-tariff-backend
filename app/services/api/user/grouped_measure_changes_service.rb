module Api
  module User
    class GroupedMeasureChangesService
      attr_reader :user, :id, :date

      def initialize(user, id = nil, date = Time.zone.yesterday)
        @user = user
        @id = id
        @date = date
      end

      def call(page: nil, per_page: nil)
        if id.present?
          measures(page, per_page)
        else
          measures_grouped
        end
      end

      private

      def measures(page, per_page)
        grouped_measure_change = TariffChanges::GroupedMeasureChange.from_id(id)
        query = build_commodity_changes_query(grouped_measure_change)
        grouped_measure_change.count = query.count

        commodity_changes_data = apply_pagination(query, page, per_page).all
        load_commodities_and_attach(grouped_measure_change, commodity_changes_data)

        grouped_measure_change
      end

      def build_commodity_changes_query(grouped_measure_change)
        excluded_areas_sorted = (grouped_measure_change.excluded_geographical_area_ids || []).sort

        TariffChange.measures
                    .with_measure_criteria(
                      trade_direction: grouped_measure_change.trade_direction_code,
                      geographical_area: grouped_measure_change.geographical_area_id,
                      excluded_areas: excluded_areas_sorted,
                    )
                    .where(operation_date: date)
                    .where(goods_nomenclature_sid: user_commodity_code_sids)
                    .group(:goods_nomenclature_item_id)
                    .order(:goods_nomenclature_item_id)
                    .select(
                      :goods_nomenclature_item_id,
                      Sequel.function(:COUNT, Sequel.lit('DISTINCT goods_nomenclature_item_id')).as(:count),
                      Sequel.lit('COUNT(*)').as(:tariff_changes_count),
                    )
      end

      def apply_pagination(query, page, per_page)
        if page.present? && per_page.present?
          query.paginate(page, per_page)
        else
          query
        end
      end

      def load_commodities_and_attach(grouped_measure_change, commodity_changes_data)
        commodity_ids = commodity_changes_data.map { |row| row.values[:goods_nomenclature_item_id] }
        commodities_by_id = load_commodities(commodity_ids)

        commodity_changes_data.each do |row|
          gn_item_id = row.values[:goods_nomenclature_item_id]
          grouped_measure_change.add_commodity_change(
            goods_nomenclature_item_id: gn_item_id,
            count: row.values[:tariff_changes_count],
          )
        end

        attach_commodities_to_changes(grouped_measure_change, commodities_by_id)
      end

      def load_commodities(commodity_ids)
        if commodity_ids.any?
          GoodsNomenclature.where(goods_nomenclature_item_id: commodity_ids)
                           .index_by(&:goods_nomenclature_item_id)
        else
          {}
        end
      end

      def attach_commodities_to_changes(grouped_measure_change, commodities_by_id)
        grouped_measure_change.grouped_measure_commodity_changes.each do |commodity_change|
          goods_nomenclature_item_id = commodity_change.goods_nomenclature_item_id
          commodity_change.commodity = commodities_by_id[goods_nomenclature_item_id]
        end
      end

      # Group changed measures by trade direction, geographical area and excluded area
      # Using JSONB metadata for much simpler grouping
      def measures_grouped
        user_commodity_code_sids = @user.target_ids_for_my_commodities
        return [] if user_commodity_code_sids.blank?

        TariffChange.measures
                    .where(operation_date: @date)
                    .where(goods_nomenclature_sid: user_commodity_code_sids)
                    .group(
                      Sequel.lit("metadata->'measure'->>'trade_movement_code'"),
                      Sequel.lit("metadata->'measure'->>'geographical_area_id'"),
                      Sequel.lit("metadata->'measure'->'excluded_geographical_area_ids'"),
                    )
                    .select(
                      Sequel.lit("metadata->'measure'->>'trade_movement_code'").as(:trade_movement_code),
                      Sequel.lit("metadata->'measure'->>'geographical_area_id'").as(:geographical_area_id),
                      Sequel.lit("metadata->'measure'->'excluded_geographical_area_ids'").as(:excluded_geographical_area_ids),
                      Sequel.function(:COUNT, Sequel.lit('DISTINCT goods_nomenclature_item_id')).as(:count),
                    )
                    .map do |row|
                      TariffChanges::GroupedMeasureChange.new(
                        trade_direction: MeasureType::TRADE_DIRECTION[row.values[:trade_movement_code].to_i],
                        count: row.values[:count],
                        geographical_area_id: row.values[:geographical_area_id],
                        excluded_geographical_area_ids: row.values[:excluded_geographical_area_ids] || [],
                      )
                    end
      end

      def user_commodity_code_sids
        @user_commodity_code_sids ||= @user.target_ids_for_my_commodities
      end
    end
  end
end
