module Reporting
  class SupplementaryUnits
    extend Reporting::Reportable

    HEADER_ROW = [
      'goods_nomenclature_item_id',
      'measure_sid',
      'measure_type_id',
      'measurement_unit_code',
      'measurement_unit_qualifier_code',
      'geographical_area_id',
    ].freeze

    class << self
      def generate
        TimeMachine.now do
          csv_data = CSV.generate(write_headers: true, headers: HEADER_ROW) do |csv|
            rows.each do |row|
              csv << row
            end
          end

          if rows.any?
            object.put(
              body: csv_data,
              content_type: 'text/csv',
            )
          end

          Rails.logger.debug("Query count: #{::SequelRails::Railties::LogSubscriber.count}")
        end
      end

      private


      def rows
        Measure
          .with_regulation_dates_query
          .where(
            measure_type_id: MeasureType::SUPPLEMENTARY_TYPES
          )
          .association_join(:measure_components)
          .select_append(
            :measure_components__measurement_unit_code,
            :measure_components__measurement_unit_qualifier_code
          )
          .order(
            :measures__goods_nomenclature_item_id,
            :measures__measure_sid
          )
          .select_map(
            [
              :goods_nomenclature_item_id,
              :measures__measure_sid,
              :measure_type_id,
              :measurement_unit_code,
              :measurement_unit_qualifier_code,
              :measures__geographical_area_id,
            ]
          )
      end

      def object_key
        "#{service}/reporting/#{year}/#{month}/#{day}/supplementary_units_#{service}_#{now.strftime('%Y_%m_%d')}.csv"
      end
    end
  end
end
