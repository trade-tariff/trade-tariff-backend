module Reporting
  class SupplementaryUnits
    extend Reporting::Reportable
    extend Reporting::Csvable

    HEADER_ROW = %w[
      goods_nomenclature_item_id
      measure_sid
      measure_type_id
      measurement_unit_code
      measurement_unit_qualifier_code
      geographical_area_id
    ].freeze

    class << self
      def generate
        save_document(object, object_key, csv_data)
        log_query_count
      end

      def csv_data
        CSV.generate(write_headers: true, headers: HEADER_ROW) do |csv|
          rows.each do |row|
            csv << row
          end
        end
      end

      def get_xi_today
        Reporting.get(object_key(tariff: 'xi'))
      end

      def get_uk_today
        Reporting.get(object_key(tariff: 'uk'))
      end

      def get_uk_link_today
        Reporting.get_link(object_key(tariff: 'uk'))
      end

      def get_xi_link_today
        Reporting.get_link(object_key(tariff: 'xi'))
      end

      private

      def rows
        TimeMachine.now do
          Measure
            .with_regulation_dates_query
            .where(
              measure_type_id: MeasureType::SUPPLEMENTARY_TYPES,
            )
            .association_inner_join(:measure_components)
            .select_append(
              :measure_components__measurement_unit_code,
              :measure_components__measurement_unit_qualifier_code,
            )
            .order(
              :measures__goods_nomenclature_item_id,
              :measures__measure_sid,
            )
            .select_map(
              %i[
                goods_nomenclature_item_id
                measures__measure_sid
                measure_type_id
                measurement_unit_code
                measurement_unit_qualifier_code
                measures__geographical_area_id
              ],
            )
        end
      end

      def object_key(tariff = service)
        "#{object_key_prefix(tariff)}/supplementary_units_#{object_key_suffix(tariff)}.csv"
      end
    end
  end
end
