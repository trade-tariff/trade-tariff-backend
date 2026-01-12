module Reporting
  class Differences
    module Renderers
      class Me32
        delegate :workbook,
                 :regular_style,
                 :bold_style,
                 to: :report

        WORKSHEET_NAME = 'ME32 candidates'.freeze

        HEADER_ROW = [
          'Commodity code',
          'Measure type',
          'Additional code',
          'Order number',
          'Geography',
          'New?',
        ].freeze

        TAB_COLOR = '00ff00'.freeze

        COLUMN_WIDTHS = [
          30, # Commodity code
          20, # Measure type
          20, # Additional code
          20, # Order number
          20, # Geography
          12, # New
        ].freeze

        METRIC = 'ME32 candidates'.freeze
        SUBTEXT = 'There may be no overlap in time with other measure occurrences with a goods code in the same nomenclature hierarchy which references the same measure type, geo area, order number and additional code.'.freeze

        def initialize(report)
          @report = report
        end

        def add_worksheet(rows)
          workbook.add_worksheet(name:) do |sheet|
            sheet.set_tab_color = TAB_COLOR
            sheet.append_row([METRIC], bold_style)
            sheet.append_row([SUBTEXT], regular_style)
            sheet.set_row(sheet.last_row_number, height: 30)
            sheet.merge_range(0, 1, 4, 1)

            sheet.append_row([FastExcel::URL.new('internal:Overview!A1')])
            sheet.write_string(2, 0, 'Back to overview', nil)

            sheet.append_row([])

            sheet.append_row(HEADER_ROW, bold_style)
            sheet.autofilter(0, 4, 4, 4)
            sheet.freeze_panes(4, 0)

            (rows || []).compact.each do |row|
              sheet.append_row(row, regular_style)
            end

            COLUMN_WIDTHS.each_with_index do |width, index|
              sheet.set_column_width(index, width)
            end
          end

          Rails.logger.debug("Query count: #{::SequelRails::Railties::LogSubscriber.count}")
        end

        def name
          WORKSHEET_NAME
        end

        attr_reader :report
      end
    end
  end
end
