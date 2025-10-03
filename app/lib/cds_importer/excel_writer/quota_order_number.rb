class CdsImporter
  class ExcelWriter
    class QuotaOrderNumber < BaseMapper
      def sheet_name
        'Quota order numbers'
      end

      def table_span
        %w[A E]
      end

      def column_widths
        [40, 20, 20, 20, 20]
      end

      def heading
        ['Action',
         'SID',
         'Order number',
         'Start date',
         'End date']
      end

      def data_row
        grouped = models.group_by { |model| model.class.name }
        qon = grouped['QuotaOrderNumber'].first

        ["#{expand_operation(qon)} quota order number",
         qon.quota_order_number_sid,
         qon.quota_order_number_id,
         format_date(qon.validity_start_date),
         format_date(qon.validity_end_date)
         ]
      end
    end
  end
end
