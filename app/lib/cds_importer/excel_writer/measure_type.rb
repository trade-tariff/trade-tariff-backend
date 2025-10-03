class CdsImporter
  class ExcelWriter
    class MeasureType < BaseMapper
      def sheet_name
        'Measure Type'
      end

      def table_span
        %w[A L]
      end

      def column_widths
        [30, 20, 20, 20, 50, 20, 20, 20, 20, 20, 20, 20]
      end

      def heading
        ['Action',
         'Measure type ID',
         'Start date',
         'End date',
         'Description',
         'Trade movement code',
         'Origin dest code',
         'Measure component applicable code',
         'Order number capture code',
         'Measure explosion level',
         'Priority code']
      end

      def data_row
        grouped = models.group_by { |model| model.class.name }
        measure_type = grouped['MeasureType'].first
        measure_type_description = grouped['MeasureTypeDescription']&.first

        ["#{expand_operation(measure_type)} measure type",
         measure_type.measure_type_id,
         format_date(measure_type.validity_start_date),
         format_date(measure_type.validity_end_date),
         measure_type_description&.description.to_s,
         measure_type.trade_movement_code,
         measure_type.origin_dest_code,
         measure_type.measure_component_applicable_code,
         measure_type.order_number_capture_code,
         measure_type.measure_explosion_level,
         measure_type.priority_code,
         ]
      end
    end
  end
end
