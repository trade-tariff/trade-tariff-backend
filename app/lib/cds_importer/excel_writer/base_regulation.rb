class CdsImporter
  class ExcelWriter
    class BaseRegulation < BaseMapper
      class << self
        def sheet_name
          'Base regulations'
        end

        def table_span
          %w[A F]
        end

        def column_widths
          [30, 20, 40, 20, 20, 20]
        end

        def heading
          ['Action',
           'Regulation ID',
           'Information text',
           'Start date',
           'Regulation group',
           'Regulation role type']
        end
      end

      def data_row
        grouped = models.group_by { |model| model.class.name }
        regulation = grouped['BaseRegulation'].first

        ["#{expand_operation(regulation)} base regulation",
         regulation.base_regulation_id,
         regulation.information_text,
         format_date(regulation.validity_start_date),
         regulation.regulation_group_id,
         regulation.base_regulation_role]
      end
    end
  end
end
