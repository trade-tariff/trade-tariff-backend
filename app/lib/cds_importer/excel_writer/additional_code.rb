class CdsImporter
  class ExcelWriter
    class AdditionalCode < BaseMapper
      def sheet_name
        'Additional codes'
      end

      def table_span
        %w[A F]
      end

      def column_widths
        [30, 20, 20, 20, 20, 50]
      end

      def heading
        ['Action',
         'Additional code type',
         'Additional code ID',
         'Start date',
         'End date',
         'Description']
      end

      def data_row
        grouped = models.group_by { |model| model.class.name }
        additional_code = grouped['AdditionalCode'].first
        additional_code_description_period = grouped['AdditionalCodeDescriptionPeriod']
        additional_code_description = grouped['AdditionalCodeDescription']

        ["#{expand_operation(additional_code)} additional code",
         additional_code.additional_code_type_id,
         additional_code.additional_code,
         format_date(additional_code.validity_start_date),
         format_date(additional_code.validity_end_date),
         periodic_description(additional_code_description_period, additional_code_description, &method(:period_matches?))
         ]
      end

      private

      def period_matches?(period, description)
        period.additional_code_description_period_sid == description.additional_code_description_period_sid &&
          period.additional_code_sid == description.additional_code_sid &&
          period.additional_code_type_id == description.additional_code_type_id &&
          period.additional_code == description.additional_code
      end
    end
  end
end
