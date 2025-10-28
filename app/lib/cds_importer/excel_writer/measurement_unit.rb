class CdsImporter
  class ExcelWriter
    class MeasurementUnit < BaseMapper
      class << self
        def sheet_name
          'Measurement Unit'
        end

        def table_span
          %w[A E]
        end

        def column_widths
          [30, 30, 30, 30, 50]
        end

        def heading
          ['Action',
           'Measurement unit code',
           'Start date',
           'End date',
           'Description']
        end
      end

      def data_row
        grouped = models.group_by { |model| model.class.name }
        measurement_unit = grouped['MeasurementUnit'].first
        measurement_unit_description = grouped['MeasurementUnitDescription']&.first

        ["#{expand_operation(measurement_unit)} measurement unit code",
         measurement_unit.measurement_unit_code,
         format_date(measurement_unit.validity_start_date),
         format_date(measurement_unit.validity_end_date),
         measurement_unit_description&.description.to_s]
      end
    end
  end
end
