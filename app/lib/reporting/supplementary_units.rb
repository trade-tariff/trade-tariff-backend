module Reporting
  class SupplementaryUnits
    include Reporting::Reportable

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
        with_report_logging do
          report_rows = instrument_report_step('load_rows') do
            TimeMachine.now { rows }
          end

          log_report_metric('rows_written', report_rows.size)

          csv_data = instrument_report_step('serialize_csv', rows_written: report_rows.size) do
            CSV.generate(write_headers: true, headers: HEADER_ROW) do |csv|
              report_rows.each do |row|
                csv << row
              end
            end
          end

          return if report_rows.empty?

          log_report_metric('output_bytes', csv_data.bytesize)

          if Rails.env.development?
            instrument_report_step('write_local_file', output_bytes: csv_data.bytesize) do
              File.write(File.basename(object_key), csv_data)
            end
          end

          if Rails.env.production?
            instrument_report_step('upload', output_bytes: csv_data.bytesize) do
              object.put(
                body: csv_data,
                content_type: 'text/csv',
              )
            end
          end
        end
      end

      def get_xi_today
        Reporting.get_published(xi_object_key)
      end

      def get_uk_today
        Reporting.get_published(uk_object_key)
      end

      def get_uk_link_today
        Reporting.published_link(uk_object_key)
      end

      def get_xi_link_today
        Reporting.published_link(xi_object_key)
      end

      private

      def rows
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

      def object_key
        "#{service}/reporting/#{year}/#{month}/#{day}/supplementary_units_#{service}_#{now.strftime('%Y_%m_%d')}.csv"
      end

      def xi_object_key
        if Rails.env.development?
          "supplementary_units_xi_#{now.strftime('%Y_%m_%d')}.csv"
        else
          "xi/reporting/#{year}/#{month}/#{day}/supplementary_units_xi_#{now.strftime('%Y_%m_%d')}.csv"
        end
      end

      def uk_object_key
        if Rails.env.development?
          "supplementary_units_uk_#{now.strftime('%Y_%m_%d')}.csv"
        else
          "uk/reporting/#{year}/#{month}/#{day}/supplementary_units_uk_#{now.strftime('%Y_%m_%d')}.csv"
        end
      end
    end
  end
end
