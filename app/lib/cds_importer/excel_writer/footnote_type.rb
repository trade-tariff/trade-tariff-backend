class CdsImporter
  class ExcelWriter
    class FootnoteType < BaseMapper
      class << self
        def sheet_name
          'Footnote types'
        end

        def table_span
          %w[A F]
        end

        def column_widths
          [30, 20, 20, 20, 20, 50]
        end

        def heading
          ['Action',
           'Footnote type ID',
           'Application code',
           'Start date',
           'End date',
           'Description']
        end
      end

      def data_row
        grouped = models.group_by { |model| model.class.name }
        footnote_type = grouped['FootnoteType'].first
        footnote_type_description = grouped['FootnoteTypeDescription']&.first

        ["#{expand_operation(footnote_type)} footnote type",
         footnote_type.footnote_type_id,
         footnote_type.application_code,
         format_date(footnote_type.validity_start_date),
         format_date(footnote_type.validity_end_date),
         footnote_type_description&.description.to_s]
      end
    end
  end
end
