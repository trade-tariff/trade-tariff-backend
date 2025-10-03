class CdsImporter
  class ExcelWriter
    class Footnote < BaseMapper
      def sheet_name
        'Footnotes'
      end

      def table_span
        %w[A G]
      end

      def column_widths
        [20, 20, 20, 20, 20, 20, 50]
      end

      def heading
        ['Action',
         'Combined',
         'Footnote type ID',
         'Footnote ID',
         'Start date',
         'End date',
         'Description']
      end

      def data_row
        grouped = models.group_by { |model| model.class.name }
        footnote = grouped['Footnote'].first
        footnote_description_periods = grouped['FootnoteDescriptionPeriod']
        footnote_descriptions = grouped['FootnoteDescription']

        ["#{expand_operation(footnote)} footnote",
         footnote.footnote_type_id + footnote.footnote_id,
         footnote.footnote_type_id,
         footnote.footnote_id,
         format_date(footnote.validity_start_date),
         format_date(footnote.validity_end_date),
         periodic_description(footnote_description_periods, footnote_descriptions, &method(:period_matches?))
         ]
      end

      private

      def period_matches?(period, description)
        period.footnote_description_period_sid == description.footnote_description_period_sid &&
          period.footnote_type_id == description.footnote_type_id &&
          period.footnote_id == description.footnote_id
      end
    end
  end
end
